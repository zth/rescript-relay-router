@module("util") external inspect: ('any, 'opts) => string = "inspect"

module Bindings = RescriptRelayRouterCli__Bindings

open RescriptRelayRouterCli__Types

type parserContext = {
  routeFileNames: array<string>,
  routeFiles: Dict.t<loadedRouteFile>,
  getRouteFileContents: string => result<string, Exn.t>,
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

let pathInRoutesFolder = (~config, ~fileName="") =>
  Bindings.Path.join([config.routesFolderPath, fileName])

module QueryParams = {
  // Decodes a raw query param type value from string to an actual type.
  // Example: "array<bool>" => Array(Boolean)
  let rec stringToQueryParam = str => {
    if str->String.startsWith("array<") {
      // Pull out the value of the array
      let arrayValue = str->String.replace("array<", "")
      let arrayValue = arrayValue->String.slice(~start=0, ~end=String.length(arrayValue) - 1)

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
        let firstChar = maybeCustomModule->String.charAt(0)
        let correctEnding = maybeCustomModule->String.endsWith(".t")

        switch correctEnding {
        | false => Error()
        | true =>
          switch (firstChar, firstChar->String.toUpperCase) {
          | ("", _) => Error()
          | (raw, uppercased) if raw == uppercased =>
            Ok(
              CustomModule({
                moduleName: maybeCustomModule->String.slice(
                  ~start=0,
                  ~end=String.length(maybeCustomModule) - 2,
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
      | Some(value) => Some(Boolean({loc, error: None, value}))
      }
    | (#string, Some(value), _) =>
      switch value->Js.Json.decodeString {
      | None => None
      | Some(value) => Some(String({loc, error: None, value}))
      }
    | (#number, Some(value), _) =>
      switch value->Js.Json.decodeNumber {
      | None => None
      | Some(value) => Some(Number({loc, error: None, value}))
      }
    | (#null, _, _) => Some(Null({loc, error: None}))
    | (#array, _, Some(children)) =>
      Some(
        Array({
          loc,
          error: None,
          children: children->Array.filterMap(child => child->transformNode(~ctx)),
        }),
      )
    | (#object, _, Some(children)) =>
      Some(
        Object({
          loc,
          error: None,
          properties: {
            let properties: array<property> = []

            children->Array.forEach(child => {
              switch (child.typ, child.children) {
              | (#property, Some([{typ: #string, value: Some(name)}, rawValue])) =>
                switch (name->Js.Json.decodeString, rawValue->transformNode(~ctx)) {
                | (Some(name), Some(value)) =>
                  properties->Array.push({
                    loc: child->rangeFromNode(~lineLookup=ctx.lineLookup),
                    name,
                    value,
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
  pathParams: array<pathParam>,
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
  let withoutQueryParams = path => path->String.split("?")->Array.get(0)->Option.getOr("")

  type inContext = ParamName | ParamCustomType | MatchBranches

  @live
  type findingPathParamsContext = {
    startChar: int,
    endChar: option<int>,
    paramName: string,
    inContext: inContext,
    currentParamCustomType: string,
    currentMatchParam: string,
    matchBranches: array<string>,
  }

  let decodePathParams = (path: string, ~loc, ~lineNum, ~ctx, ~parentContext: parentContext): array<
    pathParam,
  > => {
    let pathWithoutQueryParams = path->withoutQueryParams
    let foundPathParams = []
    let currentContext = ref(None)

    let startCharIdx = loc.start.column + 1

    let addParamIfNotAlreadyPresent = (~currentCtx, ~paramLoc) => {
      switch parentContext.seenPathParams->List.find(param => {
        let textNode = switch param.seenAtPosition {
        | PathParam({text}) => text
        | PathParamWithMatchBranches({text}) => text
        }
        textNode.text == currentCtx.paramName
      }) {
      | None =>
        let textNode = {
          loc: {
            start: {
              line: lineNum,
              column: currentCtx.startChar,
            },
            end_: {
              line: lineNum,
              column: path->String.length - 1,
            },
          },
          text: currentCtx.paramName,
        }
        foundPathParams->Array.push(
          if currentCtx.matchBranches->Array.length > 0 {
            PathParamWithMatchBranches({text: textNode, matchArms: currentCtx.matchBranches})
          } else if currentCtx.currentParamCustomType->String.length > 0 {
            PathParam({
              text: textNode,
              pathToCustomModuleWithTypeT: currentCtx.currentParamCustomType,
            })
          } else {
            PathParam({text: textNode})
          },
        )
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

    for charIdx in 0 to pathWithoutQueryParams->String.length - 1 {
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

      switch (
        currentContext.contents,
        pathWithoutQueryParams->String.get(charIdx)->Option.getOr(""),
      ) {
      | (None, ":") =>
        currentContext :=
          Some({
            startChar: startCharIdx + charIdx,
            paramName: "",
            endChar: None,
            inContext: ParamName,
            currentMatchParam: "",
            currentParamCustomType: "",
            matchBranches: [],
          })
      | (Some(currentCtx), "/") =>
        if currentCtx.paramName->String.length == 0 {
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

      | (Some({inContext: MatchBranches} as currentCtx), ")" | "|") =>
        currentContext :=
          Some({
            ...currentCtx,
            currentMatchParam: "",
            matchBranches: currentCtx.matchBranches->Array.concat([currentCtx.currentMatchParam]),
          })
      | (Some({inContext: ParamName} as currentCtx), "(") =>
        currentContext :=
          Some({
            ...currentCtx,
            inContext: MatchBranches,
          })
      | (Some({inContext: ParamName, paramName} as currentCtx), ":")
        if paramName->String.length > 0 =>
        currentContext :=
          Some({
            ...currentCtx,
            inContext: ParamCustomType,
          })
      | (Some({inContext: ParamName} as currentCtx), char) =>
        currentContext :=
          Some({
            ...currentCtx,
            paramName: currentCtx.paramName ++ char,
          })

        switch currentCtx.paramName->String.length {
        | 0 =>
          switch %re(`/[a-z]/`)->RegExp.test(char) {
          | true => ()
          | false =>
            ctx.addDecodeError(
              ~loc=charLoc,
              ~message=`Path parameters must start with a lowercase letter.`,
            )
          }
        | _ =>
          switch %re(`/[A-Za-z0-9_]/`)->RegExp.test(char) {
          | true => ()
          | false =>
            ctx.addDecodeError(
              ~loc=charLoc,
              ~message=`"${char}" is not a valid character in a path parameter. Path parameters can contain letters, digits, dots and underscores.`,
            )
          }
        }
      | (Some({inContext: ParamCustomType} as currentCtx), char) =>
        currentContext :=
          Some({
            ...currentCtx,
            currentParamCustomType: currentCtx.currentParamCustomType ++ char,
          })

        switch currentCtx.paramName->String.length {
        | 0 =>
          switch %re(`/[A-Z]/`)->RegExp.test(char) {
          | true => ()
          | false =>
            ctx.addDecodeError(
              ~loc=charLoc,
              ~message=`Path parameter type references must refer to a module, and therefore must start with an uppercase letter.`,
            )
          }
        | _ =>
          switch %re(`/[A-Za-z0-9_\.]/`)->RegExp.test(char) {
          | true => ()
          | false =>
            ctx.addDecodeError(
              ~loc=charLoc,
              ~message=`"${char}" is not a valid character in a path parameter. Path parameters can contain letters, digits, dots and underscores.`,
            )
          }
        }
      | (Some({inContext: MatchBranches} as currentCtx), char) =>
        currentContext :=
          Some({
            ...currentCtx,
            currentMatchParam: currentCtx.currentMatchParam ++ char,
          })

        switch currentCtx.currentMatchParam->String.length {
        | 0 =>
          switch %re(`/[a-zA-Z]/`)->RegExp.test(char) {
          | true => ()
          | false =>
            ctx.addDecodeError(
              ~loc=charLoc,
              ~message=`Path param match branches must start with a letter.`,
            )
          }
        | _ =>
          switch %re(`/[A-Za-z0-9_]/`)->RegExp.test(char) {
          | true => ()
          | false =>
            ctx.addDecodeError(
              ~loc=charLoc,
              ~message=`"${char}" is not a valid character in a path match branch. Path match branches can contain letters, digits, and underscores.`,
            )
          }
        }
      | _ => ()
      }
    }

    // If there's an open context when there's no more chars, it means the param goes to the end of the line.
    switch currentContext.contents {
    | None => ()
    | Some({currentParamCustomType, startChar})
      if currentParamCustomType->String.length > 0 &&
        !(currentParamCustomType->String.endsWith(".t")) =>
      ctx.addDecodeError(
        ~loc={
          start: {
            line: lineNum,
            column: startChar,
          },
          end_: {
            line: lineNum,
            column: startCharIdx + pathWithoutQueryParams->String.length,
          },
        },
        ~message=`Custom path parameters type annotations must refer to a type t in a module, hence end with ".t".`,
      )
    | Some(currentCtx) =>
      let paramLoc = {
        start: {
          line: lineNum,
          column: currentCtx.startChar,
        },
        end_: {
          line: lineNum,
          column: startCharIdx + pathWithoutQueryParams->String.length,
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
            fuzzyMatches->Array.length > 0
          ) {
            `Did you mean "${fuzzyMatches->Js.Array2.unsafe_get(0)}"?`
          } else if rawTypeText == "boolean" {
            `Did you mean "bool"?`
          } else {
            "Valid types are: string, int, float, bool, custom modules (SomeModule.t), and arrays of those."
          }
        ctx.addDecodeError(~loc=queryParamLoc, ~message)
      | Ok(queryParam) =>
        foundQueryParams->Array.push({
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
    let queryParamsStr = path->String.split("?")->Array.pop

    switch queryParamsStr {
    | None => []
    | Some(queryParamsStr) =>
      // + 1 length is accounting for the leading question mark
      let startChar = loc.start.column + path->String.length - queryParamsStr->String.length + 1

      let foundQueryParams = []
      let context = ref(None)

      for charIdx in 0 to queryParamsStr->String.length - 1 {
        let char = queryParamsStr->String.get(charIdx)->Option.getOr("")

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

      parentContext.seenQueryParams
      ->Array.concat(foundQueryParams)
      ->Array.forEach(param => {
        switch queryParamsResult->Array.some(p => p.name.text == param.name.text) {
        | true => ()
        | false => queryParamsResult->Array.push(param)
        }
      })

      queryParamsResult
    }
  }
}

module Validators = {
  open! JsoncParser

  let rec routeWithNameAlreadyExists = (existingChildren, ~routeName) => {
    existingChildren->Array.some(child =>
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
        Some({loc, name: "_"})
      | routeName =>
        switch (
          %re(`/^[A-Z][a-zA-Z0-9_]+$/`)->RegExp.test(routeName),
          siblings->routeWithNameAlreadyExists(~routeName),
        ) {
        | (true, false) => Some({loc, name: routeName})
        | (false, _) =>
          ctx.addDecodeError(
            ~loc,
            ~message=`"${routeName}" is not a valid route name. Route names need to start with an uppercase letter, and can only contain letters, digits and underscores.`,
          )
          Some({loc, name: "_"})
        | (true, _) =>
          ctx.addDecodeError(
            ~loc,
            ~message=`Duplicate route "${routeName}". Routes cannot have siblings with the same names.`,
          )
          Some({loc, name: "_"})
        }
      }
    | Some({loc, value: node}) =>
      ctx.addDecodeError(~loc, ~message=`"name" needs to be a string. Found ${nodeToString(node)}.`)
      Some({loc, name: "_"})
    | None => None
    }
  }

  let validatePath = (pathNode, ~ctx, ~parentContext: parentContext) => {
    switch pathNode {
    | Some({loc, value: String({loc: pathValueLoc, value})}) =>
      Some({
        loc,
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
      Some({loc, pathRaw: "_", pathParams: [], queryParams: []})
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
    properties->Array.find(prop => prop.name == name)

  let rec decodeRouteChildren = (
    children,
    ~ctx: currentFileContext,
    ~parentContext: parentContext,
  ) => {
    let foundChildren = []

    children->Array.forEach(child => {
      let decoded: result<routeChild, decodeError> =
        child->decodeRouteChild(~ctx, ~siblings=foundChildren, ~parentContext)
      switch decoded {
      | Error(parseError) => ctx.addDecodeError(~loc=parseError.loc, ~message=parseError.message)
      | Ok(routeChild) =>
        foundChildren->Array.push(routeChild)
        switch routeChild {
        | RouteEntry(routeEntry) =>
          parentContext.routesByName->Dict.set(
            routeEntry.name->RouteName.getFullRouteName,
            routeEntry,
          )
        | Include(_) => ()
        }
      }
    })

    foundChildren
  }
  and decodeRouteChild = (
    child: JsoncParser.node,
    ~ctx: currentFileContext,
    ~siblings,
    ~parentContext,
  ): result<routeChild, decodeError> => {
    switch child {
    | Object({loc: objLoc, properties}) =>
      let includeProp = properties->findPropertyWithName(~name="include")

      // Look for include nodes first
      switch includeProp {
      | Some({loc: keyLoc, name: "include", value: String({loc: valueLoc, value: fileName})}) =>
        // Check for invalid/illegal properties
        properties->Array.forEach(prop => {
          if prop.name != "include" {
            ctx.addDecodeError(
              ~loc=prop.loc,
              ~message=`Property "${prop.name}" is not allowed together with "include".`,
            )
          }
        })

        let errorRecoveryIncludeNode = Include({
          loc: objLoc,
          keyLoc,
          fileName: {
            loc: valueLoc,
            text: fileName,
          },
          content: [],
          parentRouteFiles: parentContext.traversedRouteFiles->List.toArray,
          parentRouteLoc: parentContext.parentRouteLoc,
        })

        // Route files must end with .json
        if !(fileName->String.endsWith(".json")) {
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
                keyLoc,
                fileName: {loc: valueLoc, text: fileName},
                content,
                parentRouteFiles: parentContext.traversedRouteFiles->List.toArray,
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
          ->Array.concat(
            parentContext.seenPathParams
            ->List.map(({seenAtPosition}) => seenAtPosition)
            ->List.toArray,
          )
          ->Array.forEach(param =>
            switch params->Array.includes(param) {
            | true => ()
            | false => params->Array.push(param)
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
              pathParams,
              routePath,
              queryParams: path.queryParams->Array.copy,
              children: None,
              sourceFile: ctx.routeFileName,
              parentRouteFiles: parentContext.traversedRouteFiles->List.toArray,
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
              pathParams,
              queryParams: [],
              routePath: RoutePath.empty(),
              children: None,
              sourceFile: ctx.routeFileName,
              parentRouteFiles: parentContext.traversedRouteFiles->List.toArray,
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
                  ...parentContext,
                  seenPathParams: List.concatMany([
                    parentContext.seenPathParams,
                    path.pathParams
                    ->List.fromArray
                    ->List.map((pathParam): seenPathParam => {
                      seenInSourceFile: ctx.routeFileName,
                      seenAtPosition: pathParam,
                    }),
                  ]),
                  currentRoutePath: routePath,
                  currentRouteNamePath: thisRouteNamePath,
                  seenQueryParams: path.queryParams,
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
              name: RouteName.make(~loc=name.loc, ~routeNamePath=thisRouteNamePath->List.reverse),
              path: {
                loc: path.loc,
                text: path.pathRaw,
              },
              routePath,
              pathParams,
              queryParams: path.queryParams->Array.copy,
              children,
              sourceFile: ctx.routeFileName,
              parentRouteFiles: parentContext.traversedRouteFiles->List.toArray,
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
      routeFileName,
      lineLookup,
      addDecodeError: (~loc, ~message) => {
        decodeErrors->Array.push({
          routeFileName,
          loc,
          message,
        })
      },
      getRouteFile: (~fileName, ~parentContext) =>
        switch (
          parserContext.routeFileNames->Array.includes(fileName),
          parserContext.routeFiles->Dict.get(fileName),
        ) {
        | (_, Some(routeFile)) => Ok(routeFile)
        | (false, _) =>
          let matched =
            fileName->Bindings.FuzzySearch.search(parserContext.routeFileNames)->Array.get(0)

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

          let loadedRouteFile = {fileName, rawText, content: result}
          parserContext.routeFiles->Dict.set(fileName, loadedRouteFile)
          Ok(loadedRouteFile)
        },
    }

    let nextParentContext = {
      ...parentContext,
      traversedRouteFiles: list{routeFileName, ...parentContext.traversedRouteFiles},
    }

    let result = switch parse(content, parseErrors) {
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
    ->Array.get(0)
    ->Option.forEach(parseError => {
      let linesAndColumns = Bindings.LinesAndColumns.make(content)

      decodeErrors->Array.push({
        routeFileName,
        message: switch parseError.error
        ->JsoncParser.decodeParseErrorCode
        ->Option.getOr(InvalidSymbol) {
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
      result,
      rawText: content,
    }
  }
}

let emptyParentCtx = (~routesByName) => {
  currentRouteNamePath: list{},
  seenQueryParams: [],
  currentRoutePath: RoutePath.empty(),
  seenPathParams: list{},
  traversedRouteFiles: list{},
  parentRouteLoc: None,
  routesByName,
}

let readRouteStructure = (~config, ~getRouteFileContents): routeStructure => {
  let routeFiles = Dict.make()
  let routesByName = Dict.make()
  let decodeErrors = []

  let {result, rawText} = "routes.json"->parseRouteFile(
    ~config,
    ~decodeErrors,
    ~parentContext=emptyParentCtx(~routesByName),
    ~parserContext={
      routeFiles,
      routeFileNames: Bindings.Glob.glob.sync(["*.json"], {cwd: pathInRoutesFolder(~config)}),
      getRouteFileContents,
    },
  )

  routeFiles->Dict.set(
    "routes.json",
    {
      fileName: "routes.json",
      rawText,
      content: result,
    },
  )

  {
    errors: decodeErrors,
    result,
    routeFiles,
    routesByName,
  }
}
