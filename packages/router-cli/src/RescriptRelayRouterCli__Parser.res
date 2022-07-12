@module("util") external inspect: ('any, 'opts) => string = "inspect"

module Bindings = RescriptRelayRouterCli__Bindings

open RescriptRelayRouterCli__Types

type parserContext = {
  routeFileNames: array<string>,
  routeFiles: Js.Dict.t<loadedRouteFile>,
  getRouteFileContents: string => Belt.Result.t<string, Js.Exn.t>,
}

type currentFileContext = {
  routeFileName: string,
  lineLookup: Bindings.LinesAndColumns.t,
  addDecodeError: (~loc: range, ~message: string) => unit,
  getRouteFile: (
    ~fileName: string,
    ~parentContext: parentContext,
  ) => result<loadedRouteFile, string>,
}

let pathInRoutesFolder = (~config, ~fileName="", ()) =>
  Bindings.Path.join([config.routesFolderPath, fileName])

module QueryParams = {
  // Decodes a raw query param type value from string to an actual type.
  // Example: "array<bool>" => Array(Boolean)
  let rec stringToQueryParam = str => {
    if str->Js.String2.startsWith("array<") {
      // Pull out the value of the array
      let arrayValue = str->Js.String2.replace("array<", "")
      let arrayValue = arrayValue->Js.String2.slice(~from=0, ~to_=Js.String2.length(arrayValue) - 1)

      switch stringToQueryParam(arrayValue) {
      | Ok(value) => Ok(Array(value))
      | err => err
      }
    } else {
      switch str {
      | "string" => Ok(String)
      | "int" => Ok(Int)
      | "float" => Ok(Float)
      | "bool" => Ok(Boolean)
      | maybeCustomModule =>
        let firstChar = maybeCustomModule->Js.String2.charAt(0)
        let correctEnding = maybeCustomModule->Js.String2.endsWith(".t")

        switch correctEnding {
        | false => Error()
        | true =>
          switch (firstChar, firstChar->Js.String2.toUpperCase) {
          | ("", _) => Error()
          | (raw, uppercased) if raw == uppercased =>
            Ok(
              CustomModule({
                moduleName: maybeCustomModule->Js.String2.slice(
                  ~from=0,
                  ~to_=Js.String2.length(maybeCustomModule) - 2,
                ),
              }),
            )
          | _ => Error()
          }
        }
      }
    }
  }
}

module ReScriptTransformer = {
  open! JsoncParser

  let rangeFromNode = (node: rawNode, ~lineLookup) => {
    start: lineLookup->Bindings.LinesAndColumns.locationForOffset(node.offset),
    end_: lineLookup->Bindings.LinesAndColumns.locationForOffset(node.offset + node.length),
  }

  let rec transformNode = (node: rawNode, ~ctx) => {
    let loc = node->rangeFromNode(~lineLookup=ctx.lineLookup)

    switch (node.typ, node.value, node.children) {
    | (#boolean, Some(value), _) =>
      switch value->Js.Json.decodeBoolean {
      | None => None
      | Some(value) => Some(Boolean({loc: loc, error: None, value: value}))
      }
    | (#string, Some(value), _) =>
      switch value->Js.Json.decodeString {
      | None => None
      | Some(value) => Some(String({loc: loc, error: None, value: value}))
      }
    | (#number, Some(value), _) =>
      switch value->Js.Json.decodeNumber {
      | None => None
      | Some(value) => Some(Number({loc: loc, error: None, value: value}))
      }
    | (#null, _, _) => Some(Null({loc: loc, error: None}))
    | (#array, _, Some(children)) =>
      Some(
        Array({
          loc: loc,
          error: None,
          children: children->Belt.Array.keepMap(child => child->transformNode(~ctx)),
        }),
      )
    | (#object, _, Some(children)) =>
      Some(
        Object({
          loc: loc,
          error: None,
          properties: {
            let properties: array<property> = []

            children->Belt.Array.forEach(child => {
              switch (child.typ, child.children) {
              | (#property, Some([{typ: #string, value: Some(name)}, rawValue])) =>
                switch (name->Js.Json.decodeString, rawValue->transformNode(~ctx)) {
                | (Some(name), Some(value)) =>
                  let _ = properties->Js.Array2.push({
                    loc: child->rangeFromNode(~lineLookup=ctx.lineLookup),
                    name: name,
                    value: value,
                  })
                | _ => ()
                }
              | _ => ()
              }
            })

            properties
          },
        }),
      )
    | _ => None
    }
  }
}

type validatedName = {
  loc: range,
  name: string,
}

type validatedPath = {
  loc: range,
  pathRaw: string,
  queryParams: array<queryParamNode>,
  pathParams: array<textNode>,
}

let dummyPos: range = {
  start: {
    line: 0,
    column: 0,
  },
  end_: {
    line: 0,
    column: 0,
  },
}

module Path = {
  let withoutQueryParams = path =>
    path->Js.String2.split("?")->Belt.Array.get(0)->Belt.Option.getWithDefault("")

  @live
  type findingPathParamsContext = {
    startChar: int,
    endChar: option<int>,
    paramName: string,
  }

  let decodePathParams = (path: string, ~loc, ~lineNum, ~ctx, ~parentContext: parentContext): array<
    textNode,
  > => {
    let pathWithoutQueryParams = path->withoutQueryParams
    let foundPathParams = []
    let currentContext = ref(None)

    let startCharIdx = loc.start.column + 1

    let addParamIfNotAlreadyPresent = (~currentCtx, ~paramLoc) => {
      switch parentContext.seenPathParams->Belt.List.getBy(param =>
        param.seenAtPosition.text == currentCtx.paramName
      ) {
      | None =>
        let _ = foundPathParams->Js.Array2.push({
          loc: {
            start: {
              line: lineNum,
              column: currentCtx.startChar,
            },
            end_: {
              line: lineNum,
              column: path->Js.String2.length - 1,
            },
          },
          text: currentCtx.paramName,
        })
      | Some(alreadySeenPathParam) =>
        // Same file
        if alreadySeenPathParam.seenInSourceFile == ctx.routeFileName {
          ctx.addDecodeError(
            ~loc=paramLoc,
            ~message=`Path parameter "${currentCtx.paramName}" already exists in route "${alreadySeenPathParam.seenInSourceFile}". Path parameters cannot appear more than once per full path.`,
          )
        } else {
          // Other file
          ctx.addDecodeError(
            ~loc=paramLoc,
            ~message=`Path parameter "${currentCtx.paramName}" already exists in file "${alreadySeenPathParam.seenInSourceFile}" (route with name "${alreadySeenPathParam.seenInSourceFile}"), which is a parent to this route. Path names need to be unique per full route, including parents/children.`,
          )
        }
      }
    }

    for charIdx in 0 to pathWithoutQueryParams->Js.String2.length - 1 {
      let charLoc = {
        start: {
          line: lineNum,
          column: startCharIdx + charIdx,
        },
        end_: {
          line: lineNum,
          column: startCharIdx + charIdx + 1,
        },
      }

      switch (currentContext.contents, pathWithoutQueryParams->Js.String2.get(charIdx)) {
      | (None, ":") =>
        currentContext :=
          Some({
            startChar: startCharIdx + charIdx,
            paramName: "",
            endChar: None,
          })
      | (Some(currentCtx), "/") =>
        if currentCtx.paramName->Js.String2.length == 0 {
          ctx.addDecodeError(
            ~loc={
              start: {
                line: lineNum,
                column: startCharIdx + charIdx - 1,
              },
              end_: {
                line: lineNum,
                column: startCharIdx + charIdx,
              },
            },
            ~message=`Path parameter names cannot be empty.`,
          )
        }

        let paramLoc = {
          start: {
            line: lineNum,
            column: currentCtx.startChar,
          },
          end_: {
            line: lineNum,
            column: startCharIdx + charIdx - 1,
          },
        }

        addParamIfNotAlreadyPresent(~currentCtx, ~paramLoc)

        currentContext := None
      | (Some(currentCtx), char) =>
        currentContext :=
          Some({
            ...currentCtx,
            paramName: currentCtx.paramName ++ char,
          })

        switch currentCtx.paramName->Js.String2.length {
        | 0 =>
          switch %re(`/[a-z]/`)->Js.Re.test_(char) {
          | true => ()
          | false =>
            ctx.addDecodeError(
              ~loc=charLoc,
              ~message=`Path parameters must start with a lowercase letter.`,
            )
          }
        | _ =>
          switch %re(`/[A-Za-z0-9_]/`)->Js.Re.test_(char) {
          | true => ()
          | false =>
            ctx.addDecodeError(
              ~loc=charLoc,
              ~message=`"${char}" is not a valid character in a path parameter. Path parameters can contain letters, digits, and underscores.`,
            )
          }
        }

      | _ => ()
      }
    }

    // If there's an open context when there's no more chars, it means the param goes to the end of the line.
    switch currentContext.contents {
    | None => ()
    | Some(currentCtx) =>
      let paramLoc = {
        start: {
          line: lineNum,
          column: currentCtx.startChar,
        },
        end_: {
          line: lineNum,
          column: startCharIdx + pathWithoutQueryParams->Js.String2.length,
        },
      }

      addParamIfNotAlreadyPresent(~currentCtx, ~paramLoc)
    }

    foundPathParams
  }

  type findingQueryParamsContext = {
    keyStartChar: int,
    keyEndChar: option<int>,
    typeStartChar: option<int>,
    typeEndChar: option<int>,
    key: string,
    rawTypeText: option<string>,
  }

  let queryParamNames = ["string", "int", "float", "bool", "array"]

  let handleCompletedParam = (~completedParamCtx, ~ctx, ~foundQueryParams, ~lineNum) => {
    switch completedParamCtx {
    | {
        key,
        keyStartChar,
        keyEndChar: Some(keyEndChar),
        typeStartChar: Some(typeStartChar),
        typeEndChar: Some(typeEndChar),
        rawTypeText: Some(rawTypeText),
      } =>
      let queryParamLoc = {
        start: {line: lineNum, column: typeStartChar},
        end_: {line: lineNum, column: typeEndChar},
      }
      let keyLoc = {
        start: {line: lineNum, column: keyStartChar},
        end_: {line: lineNum, column: keyEndChar},
      }
      switch QueryParams.stringToQueryParam(rawTypeText) {
      | Error() =>
        let fuzzyMatches = rawTypeText->Bindings.FuzzySearch.search(queryParamNames)

        let message =
          `"${rawTypeText}" is not a valid query param type.\n  ` ++ if (
            fuzzyMatches->Js.Array2.length > 0
          ) {
            `Did you mean "${fuzzyMatches->Js.Array2.unsafe_get(0)}"?`
          } else if rawTypeText == "boolean" {
            `Did you mean "bool"?`
          } else {
            "Valid types are: string, int, float, bool, custom modules (SomeModule.t), and arrays of those."
          }
        ctx.addDecodeError(~loc=queryParamLoc, ~message)
      | Ok(queryParam) =>
        let _ = foundQueryParams->Js.Array2.push({
          name: {
            text: key,
            loc: keyLoc,
          },
          queryParam: (queryParamLoc, queryParam),
        })
      }

    | _ => ()
    }
  }

  let decodeQueryParams = (
    path: string,
    ~loc,
    ~lineNum,
    ~ctx,
    ~parentContext: parentContext,
  ): array<queryParamNode> => {
    let queryParamsStr = path->Js.String2.split("?")->Js.Array2.pop

    switch queryParamsStr {
    | None => []
    | Some(queryParamsStr) =>
      // + 1 length is accounting for the leading question mark
      let startChar =
        loc.start.column + path->Js.String2.length - queryParamsStr->Js.String2.length + 1

      let foundQueryParams = []
      let context = ref(None)

      for charIdx in 0 to queryParamsStr->Js.String2.length - 1 {
        let char = queryParamsStr->Js.String2.get(charIdx)

        switch (context.contents, char) {
        | (Some(completedParamCtx), "&") =>
          // This means the next param is coming up, so we can commit whatever we have.
          handleCompletedParam(
            ~completedParamCtx={...completedParamCtx, typeEndChar: Some(startChar + charIdx)},
            ~ctx,
            ~foundQueryParams,
            ~lineNum,
          )
          context := None
        | (Some(completedParamCtx), "=") =>
          // This means we're moving from looking at the param name to the param type
          context :=
            Some({
              ...completedParamCtx,
              keyEndChar: Some(startChar + charIdx - 1),
              typeStartChar: Some(startChar + charIdx + 1),
              rawTypeText: Some(""),
            })
        | (None, char) =>
          // Means we're just getting started on a new param
          context :=
            Some({
              keyStartChar: startChar + charIdx,
              keyEndChar: None,
              typeStartChar: None,
              typeEndChar: None,
              key: char,
              rawTypeText: None,
            })
        | (Some({rawTypeText: None} as ctx), char) =>
          // Still in the key, add to that
          context := Some({...ctx, key: ctx.key ++ char})
        | (Some({rawTypeText: Some(rawTypeText)} as ctx), char) =>
          // In the type text, add to that
          context := Some({...ctx, rawTypeText: Some(rawTypeText ++ char)})
        }
      }

      // If there's a trailing, unclosed param, we can assume that type ends at
      // the end of the string. Commit.
      switch context.contents {
      | None => ()
      | Some(completedParamCtx) =>
        handleCompletedParam(
          ~completedParamCtx={...completedParamCtx, typeEndChar: Some(loc.end_.column - 1)},
          ~foundQueryParams,
          ~lineNum,
          ~ctx,
        )
      }

      // Merge the newly found params with the existing parameters inherited from the parents
      let queryParamsResult: array<queryParamNode> = []

      []
      ->Js.Array2.concatMany([parentContext.seenQueryParams, foundQueryParams])
      ->Belt.Array.forEach(param => {
        switch queryParamsResult->Belt.Array.some(p => p.name.text == param.name.text) {
        | true => ()
        | false =>
          let _ = queryParamsResult->Js.Array2.push(param)
        }
      })

      queryParamsResult
    }
  }
}

module Validators = {
  open! JsoncParser

  let rec routeWithNameAlreadyExists = (existingChildren, ~routeName) => {
    existingChildren->Js.Array2.some(child =>
      switch child {
      | RouteEntry({name}) if name->RouteName.getRouteName == routeName => true
      | Include({content: children}) => children->routeWithNameAlreadyExists(~routeName)
      | _ => false
      }
    )
  }

  let validateName = (nameNode, ~ctx, ~siblings) => {
    switch nameNode {
    | Some({value: String({loc, value})}) =>
      switch value {
      | "Route" =>
        ctx.addDecodeError(
          ~loc,
          ~message=`"Route" is a reserved name. Please change your route name to something else.`,
        )
        Some({loc: loc, name: "_"})
      | routeName =>
        switch (
          %re(`/^[A-Z][a-zA-Z0-9_]+$/`)->Js.Re.test_(routeName),
          siblings->routeWithNameAlreadyExists(~routeName),
        ) {
        | (true, false) => Some({loc: loc, name: routeName})
        | (false, _) =>
          ctx.addDecodeError(
            ~loc,
            ~message=`"${routeName}" is not a valid route name. Route names need to start with an uppercase letter, and can only contain letters, digits and underscores.`,
          )
          Some({loc: loc, name: "_"})
        | (true, _) =>
          ctx.addDecodeError(
            ~loc,
            ~message=`Duplicate route "${routeName}". Routes cannot have siblings with the same names.`,
          )
          Some({loc: loc, name: "_"})
        }
      }
    | Some({loc, value: node}) =>
      ctx.addDecodeError(~loc, ~message=`"name" needs to be a string. Found ${nodeToString(node)}.`)
      Some({loc: loc, name: "_"})
    | None => None
    }
  }

  let validatePath = (pathNode, ~ctx, ~parentContext: parentContext) => {
    switch pathNode {
    | Some({loc, value: String({loc: pathValueLoc, value})}) =>
      Some({
        loc: loc,
        pathRaw: value,
        pathParams: value->Path.decodePathParams(
          ~lineNum=loc.start.line,
          ~ctx,
          ~loc=pathValueLoc,
          ~parentContext,
        ),
        queryParams: value->Path.decodeQueryParams(
          ~lineNum=loc.start.line,
          ~ctx,
          ~loc=pathValueLoc,
          ~parentContext,
        ),
      })
    | Some({loc, value: node}) =>
      ctx.addDecodeError(~loc, ~message=`"path" needs to be a string. Found ${nodeToString(node)}.`)
      Some({loc: loc, pathRaw: "_", pathParams: [], queryParams: []})
    | None => None
    }
  }
}

module Decode = {
  open! JsoncParser

  let locFromNode = node =>
    switch node {
    | Array({loc})
    | Object({loc})
    | String({loc})
    | Number({loc})
    | Boolean({loc})
    | Null({loc}) => loc
    }

  let findPropertyWithName = (properties, ~name) =>
    properties->Belt.Array.getBy(prop => prop.name == name)

  let rec decodeRouteChildren = (children, ~ctx, ~parentContext) => {
    let foundChildren = []

    children->Belt.Array.forEach(child =>
      switch child->decodeRouteChild(~ctx, ~siblings=foundChildren, ~parentContext) {
      | Error(parseError) =>
        let _ = ctx.addDecodeError(~loc=parseError.loc, ~message=parseError.message)
      | Ok(routeChild) =>
        let _ = foundChildren->Js.Array2.push(routeChild)
      }
    )

    foundChildren
  }
  and decodeRouteChild = (child, ~ctx, ~siblings, ~parentContext): Belt.Result.t<
    routeChild,
    decodeError,
  > => {
    switch child {
    | Object({loc: objLoc, properties}) =>
      let includeProp = properties->findPropertyWithName(~name="include")

      // Look for include nodes first
      switch includeProp {
      | Some({loc: keyLoc, name: "include", value: String({loc: valueLoc, value: fileName})}) =>
        // Check for invalid/illegal properties
        properties->Belt.Array.forEach(prop => {
          if prop.name != "include" {
            ctx.addDecodeError(
              ~loc=prop.loc,
              ~message=`Property "${prop.name}" is not allowed together with "include".`,
            )
          }
        })

        let errorRecoveryIncludeNode = Include({
          loc: objLoc,
          keyLoc: keyLoc,
          fileName: {
            loc: valueLoc,
            text: fileName,
          },
          content: [],
          parentRouteFiles: parentContext.traversedRouteFiles->Belt.List.toArray,
          parentRouteLoc: parentContext.parentRouteLoc,
        })

        // Route files must end with .json
        if !(fileName->Js.String2.endsWith(".json")) {
          ctx.addDecodeError(
            ~loc=valueLoc,
            ~message=`Route file to include must have .json extension.`,
          )
          Ok(errorRecoveryIncludeNode)
        } else {
          switch ctx.getRouteFile(~fileName, ~parentContext) {
          | Error(message) =>
            ctx.addDecodeError(~loc=objLoc, ~message)

            Ok(errorRecoveryIncludeNode)
          | Ok({content}) =>
            Ok(
              Include({
                loc: objLoc,
                keyLoc: keyLoc,
                fileName: {loc: valueLoc, text: fileName},
                content: content,
                parentRouteFiles: parentContext.traversedRouteFiles->Belt.List.toArray,
                parentRouteLoc: parentContext.parentRouteLoc,
              }),
            )
          }
        }
      | Some(_) | None =>
        let pathProp = properties->findPropertyWithName(~name="path")
        let nameProp = properties->findPropertyWithName(~name="name")
        let children = properties->findPropertyWithName(~name="children")

        let name = nameProp->Validators.validateName(~ctx, ~siblings)
        let path = pathProp->Validators.validatePath(~ctx, ~parentContext)

        // Params are inherited from all parent routes. This concatenates the
        // previously seen path params from the parents.
        let pathParams = switch path {
        | None => []
        | Some({pathParams}) =>
          let params = []
          pathParams
          ->Belt.Array.concat(
            parentContext.seenPathParams
            ->Belt.List.map(({seenAtPosition}) => seenAtPosition)
            ->Belt.List.toArray,
          )
          ->Belt.Array.forEach(param =>
            switch params->Js.Array2.includes(param) {
            | true => ()
            | false =>
              let _ = params->Js.Array2.push(param)
            }
          )

          params
        }

        switch (path, name) {
        // Hitting only one of these means we can assume the user is trying to build a route entry, but missing props
        | (Some(path), None) =>
          ctx.addDecodeError(~loc=objLoc, ~message=`This route entry is missing the "name" prop.`)
          let routePath =
            path.pathRaw->RoutePath.make(~currentRoutePath=parentContext.currentRoutePath)

          Ok(
            RouteEntry({
              loc: objLoc,
              name: RouteName.make(~loc=dummyPos, ~routeNamePath=list{"_"}),
              path: {
                loc: path.loc,
                text: path.pathRaw,
              },
              pathParams: pathParams,
              routePath: routePath,
              queryParams: path.queryParams->Js.Array2.copy,
              children: None,
              sourceFile: ctx.routeFileName,
              parentRouteFiles: parentContext.traversedRouteFiles->Belt.List.toArray,
              parentRouteLoc: parentContext.parentRouteLoc,
            }),
          )
        | (None, Some(name)) =>
          ctx.addDecodeError(~loc=objLoc, ~message=`This route entry is missing the "path" prop.`)
          Ok(
            RouteEntry({
              loc: objLoc,
              name: RouteName.make(~loc=name.loc, ~routeNamePath=list{"_"}),
              path: {
                loc: dummyPos,
                text: "_",
              },
              pathParams: pathParams,
              queryParams: [],
              routePath: RoutePath.empty(),
              children: None,
              sourceFile: ctx.routeFileName,
              parentRouteFiles: parentContext.traversedRouteFiles->Belt.List.toArray,
              parentRouteLoc: parentContext.parentRouteLoc,
            }),
          )
        | (Some(path), Some(name)) =>
          // Everything matches
          let thisRouteNamePath = list{name.name, ...parentContext.currentRouteNamePath}
          let routePath =
            path.pathRaw->RoutePath.make(~currentRoutePath=parentContext.currentRoutePath)

          let children = switch children {
          | Some({value: Array({children, loc})}) =>
            Some(
              children->decodeRouteChildren(
                ~ctx,
                ~parentContext={
                  seenPathParams: Belt.List.concatMany([
                    parentContext.seenPathParams,
                    path.pathParams
                    ->Belt.List.fromArray
                    ->Belt.List.map((pathParam): seenPathParam => {
                      seenInSourceFile: ctx.routeFileName,
                      seenAtPosition: pathParam,
                    }),
                  ]),
                  currentRoutePath: routePath,
                  currentRouteNamePath: thisRouteNamePath,
                  seenQueryParams: path.queryParams,
                  traversedRouteFiles: parentContext.traversedRouteFiles,
                  parentRouteLoc: Some({
                    childrenArray: loc,
                  }),
                },
              ),
            )
          | _ => None
          }

          Ok(
            RouteEntry({
              loc: objLoc,
              name: RouteName.make(
                ~loc=name.loc,
                ~routeNamePath=thisRouteNamePath->Belt.List.reverse,
              ),
              path: {
                loc: path.loc,
                text: path.pathRaw,
              },
              routePath: routePath,
              pathParams: pathParams,
              queryParams: path.queryParams->Js.Array2.copy,
              children: children,
              sourceFile: ctx.routeFileName,
              parentRouteFiles: parentContext.traversedRouteFiles->Belt.List.toArray,
              parentRouteLoc: parentContext.parentRouteLoc,
            }),
          )

        | _ =>
          Error({
            routeFileName: ctx.routeFileName,
            loc: objLoc,
            message: "Invalid route entry found.",
          })
        }
      }

    | node =>
      Error({
        routeFileName: ctx.routeFileName,
        loc: locFromNode(node),
        message: `Routes must be objects. Found ${nodeToString(node)}.`,
      })
    }
  }

  let decode = (node: option<node>, ~ctx, ~parentContext): array<routeChild> => {
    switch node {
    // No content
    | None =>
      ctx.addDecodeError(
        ~loc={
          start: ctx.lineLookup->Bindings.LinesAndColumns.locationForOffset(0),
          end_: ctx.lineLookup->Bindings.LinesAndColumns.locationForOffset(0),
        },
        ~message="Empty file..",
      )

      []
    // Wrong top level
    | Some(
        (Object({loc}) | String({loc}) | Number({loc}) | Boolean({loc}) | Null({loc})) as node,
      ) =>
      ctx.addDecodeError(
        ~loc,
        ~message=`Route files must have a top level array. Found ${nodeToString(node)}.`,
      )
      []
    | Some(Array({loc, children: []})) =>
      ctx.addDecodeError(~loc, ~message=`Empty route file. Route files should not be empty.`)
      []
    | Some(Array({children, loc})) =>
      children->decodeRouteChildren(
        ~ctx,
        ~parentContext={
          ...parentContext,
          parentRouteLoc: Some({
            childrenArray: loc,
          }),
        },
      )
    }
  }
}

type result = {
  result: array<routeChild>,
  rawText: string,
}

let rec parseRouteFile = (
  routeFileName,
  ~config,
  ~decodeErrors,
  ~parserContext,
  ~parentContext,
): result => {
  open JsoncParser

  let parseErrors = []

  let content = parserContext.getRouteFileContents(routeFileName)

  switch content {
  | Error(_) => {
      result: [],
      rawText: "",
    }

  | Ok(content) =>
    let lineLookup = Bindings.LinesAndColumns.make(content)

    let ctx = {
      routeFileName: routeFileName,
      lineLookup: lineLookup,
      addDecodeError: (~loc, ~message) => {
        let _ = decodeErrors->Js.Array2.push({
          routeFileName: routeFileName,
          loc: loc,
          message: message,
        })
      },
      getRouteFile: (~fileName, ~parentContext) =>
        switch (
          parserContext.routeFileNames->Js.Array2.includes(fileName),
          parserContext.routeFiles->Js.Dict.get(fileName),
        ) {
        | (_, Some(routeFile)) => Ok(routeFile)
        | (false, _) =>
          let matched =
            fileName->Bindings.FuzzySearch.search(parserContext.routeFileNames)->Belt.Array.get(0)

          Error(
            `"${fileName}" could not be found. ${switch matched {
              | None => `Does it exist?`
              | Some(name) => `Did you mean "${name}"?`
              }}`,
          )
        | (true, None) =>
          let {rawText, result} = parseRouteFile(
            fileName,
            ~config,
            ~parserContext,
            ~decodeErrors,
            ~parentContext,
          )

          let loadedRouteFile = {fileName: fileName, rawText: rawText, content: result}
          parserContext.routeFiles->Js.Dict.set(fileName, loadedRouteFile)
          Ok(loadedRouteFile)
        },
    }

    let nextParentContext = {
      ...parentContext,
      traversedRouteFiles: list{routeFileName, ...parentContext.traversedRouteFiles},
    }

    let result = switch parse(content, parseErrors, ()) {
    | Some(node) =>
      node
      ->ReScriptTransformer.transformNode(~ctx)
      ->Decode.decode(~ctx, ~parentContext=nextParentContext)
    | None => None->Decode.decode(~ctx, ~parentContext=nextParentContext)
    }

    // Use only the first parse error, since broken sources might produce a ton
    // of parse errors, and that's just annoying. Essentially, all you need to
    // know is that syntax is broken - fix it, and if there are still errors
    // you'll get them 1 by 1.
    parseErrors
    ->Belt.Array.get(0)
    ->Belt.Option.forEach(parseError => {
      let linesAndColumns = Bindings.LinesAndColumns.make(content)

      let _ = decodeErrors->Js.Array2.push({
        routeFileName: routeFileName,
        message: switch parseError.error
        ->JsoncParser.decodeParseErrorCode
        ->Belt.Option.getWithDefault(InvalidSymbol) {
        | InvalidSymbol => "Invalid symbol."
        | InvalidNumberFormat => "Invalid number format."
        | PropertyNameExpected => "Expected property name."
        | ValueExpected => "Expected value."
        | ColonExpected => "Expected colon."
        | CommaExpected => "Expected comma."
        | CloseBraceExpected => "Expected close brace."
        | CloseBracketExpected => "Expected close bracket."
        | EndOfFileExpected => "Expected end of file."
        | InvalidCommentToken => "Invalid comment token."
        | UnexpectedEndOfComment => "Unexpected end of comment."
        | UnexpectedEndOfString => "Unexpected end of string."
        | UnexpectedEndOfNumber => "Unexpected end of number."
        | InvalidUnicode => "Invalid unicode."
        | InvalidEscapeCharacter => "Invalid escape character."
        | InvalidCharacter => "Invalid character."
        },
        loc: {
          start: linesAndColumns->Bindings.LinesAndColumns.locationForOffset(parseError.offset),
          end_: linesAndColumns->Bindings.LinesAndColumns.locationForOffset(
            parseError.offset + parseError.length,
          ),
        },
      })
    })

    {
      result: result,
      rawText: content,
    }
  }
}

let emptyParentCtx = () => {
  currentRouteNamePath: list{},
  seenQueryParams: [],
  currentRoutePath: RoutePath.empty(),
  seenPathParams: list{},
  traversedRouteFiles: list{},
  parentRouteLoc: None,
}

let readRouteStructure = (~config, ~getRouteFileContents): routeStructure => {
  let routeFiles = Js.Dict.empty()
  let decodeErrors = []

  let {result, rawText} = "routes.json"->parseRouteFile(
    ~config,
    ~decodeErrors,
    ~parentContext=emptyParentCtx(),
    ~parserContext={
      routeFiles: routeFiles,
      routeFileNames: Bindings.Glob.glob.sync(
        ["*.json"],
        Bindings.Glob.opts(~cwd=pathInRoutesFolder(~config, ()), ()),
      ),
      getRouteFileContents: getRouteFileContents,
    },
  )

  routeFiles->Js.Dict.set(
    "routes.json",
    {
      fileName: "routes.json",
      rawText: rawText,
      content: result,
    },
  )

  {
    errors: decodeErrors,
    result: result,
    routeFiles: routeFiles,
  }
}