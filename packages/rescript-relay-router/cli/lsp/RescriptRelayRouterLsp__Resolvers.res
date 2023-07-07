open RescriptRelayRouterCli__Types
module Bindings = RescriptRelayRouterCli__Bindings
module Utils = RescriptRelayRouterCli__Utils
module LspUtils = RescriptRelayRouterLsp__Utils

type lspResolveContext = {
  fileUri: string,
  pos: LspProtocol.loc,
  config: RescriptRelayRouterCli__Types.config,
  routeFileNames: array<string>,
}

let mapRange = (range: range): LspProtocol.range => {
  start: {
    line: range.start.line,
    character: range.start.column,
  },
  end_: {
    line: range.end_.line,
    character: range.end_.column,
  },
}

let mapPos = (loc: loc): LspProtocol.loc => {
  line: loc.line,
  character: loc.column,
}

let mapRangeFromStartOnly = (range: range): LspProtocol.range => {
  start: {
    line: range.start.line,
    character: range.start.column,
  },
  end_: {
    line: range.start.line,
    character: range.start.column,
  },
}

let toRouteFileName = fileUri => Bindings.Path.basename(fileUri)

module AstIterator = {
  let hasPos = (range: LspProtocol.range, ~pos: LspProtocol.loc) => {
    let pos = (pos.line, pos.character)

    let posStart = (range.start.line, range.start.character)
    let posEnd = (range.end_.line, range.end_.character)

    posStart <= pos && pos <= posEnd
  }

  type includeEntryAstLocation = FileName(textNode) | Key(range)

  @live
  type routeEntryPathAstLocation =
    | Key(range)
    | FullPath({path: textNode})

  @live
  type routeEntryNameAstLocation = Key(range) | NameText(textNode)

  @live
  type routeEntryAstLocation =
    Key(range) | Path(routeEntryPathAstLocation) | Name(routeEntryNameAstLocation)

  type astLocation =
    | IncludeEntry({includeEntry: includeEntry, innerLocation: option<includeEntryAstLocation>})
    | RouteEntry({routeEntry: routeEntry, innerLocation: option<routeEntryAstLocation>})

  let rec findPosInRouteChildren = (children: array<routeChild>, ~ctx: lspResolveContext): option<
    astLocation,
  > => {
    let {pos} = ctx
    let children = children->Array.copy
    let break = ref(false)
    let foundContext = ref(None)

    let breakNow = () => break := true
    let setFoundContext = ctx => {
      foundContext := Some(ctx)
      breakNow()
    }

    while break.contents == false {
      switch children->Array.shift {
      | None => breakNow()
      | Some(Include({loc, fileName, keyLoc, content} as includeEntry))
        if loc->mapRange->hasPos(~pos) =>
        switch (fileName.loc->mapRange->hasPos(~pos), keyLoc->mapRange->hasPos(~pos)) {
        | (true, _) =>
          setFoundContext(
            IncludeEntry({
              includeEntry,
              innerLocation: Some(FileName(fileName)),
            }),
          )

        | (_, true) =>
          setFoundContext(
            IncludeEntry({
              includeEntry,
              innerLocation: Some(Key(keyLoc)),
            }),
          )
        | _ =>
          switch content->findPosInRouteChildren(~ctx) {
          | None =>
            setFoundContext(
              IncludeEntry({
                includeEntry,
                innerLocation: None,
              }),
            )
          | Some(astLocation) => setFoundContext(astLocation)
          }
        }
        ()
      | Some(RouteEntry({loc, name, path} as routeEntry)) if loc->mapRange->hasPos(~pos) =>
        switch (name->RouteName.getLoc->mapRange->hasPos(~pos), path.loc->mapRange->hasPos(~pos)) {
        | (true, _) =>
          setFoundContext(
            RouteEntry({
              routeEntry,
              innerLocation: Some(
                Name(
                  NameText({
                    loc: name->RouteName.getLoc,
                    text: name->RouteName.getRouteName,
                  }),
                ),
              ),
            }),
          )
        | (_, true) =>
          setFoundContext(
            RouteEntry({
              routeEntry,
              innerLocation: Some(Path(FullPath({path: path}))),
            }),
          )
        | (false, false) =>
          switch routeEntry.children->Option.getWithDefault([])->findPosInRouteChildren(~ctx) {
          | None =>
            setFoundContext(
              RouteEntry({
                routeEntry,
                innerLocation: None,
              }),
            )
          | Some(astLocation) => setFoundContext(astLocation)
          }
        }

      | _ => ()
      }
    }

    foundContext.contents
  }

  @live
  let findPosContext = (routeStructure: routeStructure, ~ctx: lspResolveContext) => {
    routeStructure.result->findPosInRouteChildren(~ctx)
  }
}

let findRequestContext = (routeStructure: routeStructure, ~ctx: lspResolveContext): option<
  AstIterator.astLocation,
> => {
  let routeFileName = ctx.fileUri->toRouteFileName

  switch routeStructure.routeFiles->Dict.get(routeFileName) {
  | None =>
    ()
    None
  | Some({content}) => content->AstIterator.findPosInRouteChildren(~ctx)
  }
}

let hover = (routeStructure: routeStructure, ~ctx: lspResolveContext): option<
  LspProtocol.hover,
> => {
  switch routeStructure->findRequestContext(~ctx) {
  | None => None
  | Some(astLocation) =>
    switch astLocation {
    | IncludeEntry({innerLocation}) =>
      switch innerLocation {
      | Some(FileName(fileName)) =>
        Some(
          LspProtocol.makeHover(
            ~loc=fileName.loc->mapRange,
            ~message=`Filename: "${fileName.text}"`,
          ),
        )
      | Some(Key(keyLoc)) =>
        Some(LspProtocol.makeHover(~loc=keyLoc->mapRange, ~message=`Defines an include attribute.`))
      | None => None
      }
    | RouteEntry({routeEntry}) =>
      let routeName = routeEntry.name->RouteName.getFullRouteName
      let genericRouteEntryHover = LspProtocol.makeHover(
        ~loc=routeEntry.loc->mapRange,
        ~message=`
**Full route name**\n
\`${routeName}\`
\n

**Full route path**\n
\`${routeEntry.routePath->RoutePath.getFullRoutePath}\`
`,
      )

      Some(genericRouteEntryHover)
    }
  }
}

let resolveRouteFileCompletions = (
  matchText: string,
  ~includeEntry: includeEntry,
  ~ctx: lspResolveContext,
): array<LspProtocol.completionItem> => {
  let currentFileName = ctx.fileUri->Bindings.Path.basename

  let potentialMatches =
    ctx.routeFileNames->Array.filter(routeFileName =>
      routeFileName != currentFileName &&
        !(includeEntry.parentRouteFiles->Array.includes(routeFileName))
    )

  if matchText == "" {
    potentialMatches->Array.map(matchedLabel =>
      LspProtocol.makeCompletionItem(~label=matchedLabel, ~kind=Class)
    )
  } else {
    matchText
    ->Bindings.FuzzySearch.search(potentialMatches)
    ->Array.map(matchedLabel => LspProtocol.makeCompletionItem(~label=matchedLabel, ~kind=Class))
  }
}

let completion = (routeStructure: routeStructure, ~ctx: lspResolveContext): option<
  array<LspProtocol.completionItem>,
> => {
  switch routeStructure->findRequestContext(~ctx) {
  | None => None
  | Some(astLocation) =>
    let emptyCompletionList = []
    switch astLocation {
    | IncludeEntry({includeEntry, innerLocation}) =>
      switch innerLocation {
      | Some(FileName(fileName)) =>
        let res = fileName.text->resolveRouteFileCompletions(~ctx, ~includeEntry)
        Some(res)
      | Some(Key(_keyLoc)) => Some(emptyCompletionList)
      | None => None
      }
    | RouteEntry({innerLocation}) =>
      switch innerLocation {
      | Some(innerLocation) =>
        switch innerLocation {
        | Name(NameText(_)) => None
        | Name(Key(_)) => None
        | Key(_) => Some(emptyCompletionList)
        | Path(Key(_keyLoc)) => Some(emptyCompletionList)
        | Path(FullPath({path: _})) => Some(emptyCompletionList)
        }
      | None => None
      }
    }
  }
}

let codeActions = (routeStructure: routeStructure, ~ctx: lspResolveContext): option<
  array<LspProtocol.codeAction>,
> => {
  switch routeStructure->findRequestContext(~ctx) {
  | None => None
  | Some(astLocation) =>
    switch astLocation {
    | RouteEntry({routeEntry: {parentRouteLoc: Some({childrenArray})}}) =>
      Some([
        {
          title: "Add route entry",
          kind: Refactor->LspProtocol.codeActionKindToString->Some,
          isPreferred: None,
          edit: Some({
            documentChanges: Some([
              LspProtocol.DocumentChange.TextDocumentEdit.make(
                ~textDocumentUri=ctx.fileUri,
                ~edits=[
                  {
                    range: {
                      start: childrenArray.end_->mapPos,
                      end_: childrenArray.end_->mapPos,
                    },
                    newText: "{}",
                  },
                ],
              ),
            ]),
          }),
        },
      ])
    | _ => None
    }
  }
}

let codeLens = (routeStructure: routeStructure, ~ctx: lspResolveContext): option<
  array<LspProtocol.codeLens>,
> => {
  let lenses: array<LspProtocol.codeLens> = []
  let addLens = (~range, ~command) => {
    lenses->Array.push(LspProtocol.makeCodeLensItem(~command, ~range))
  }

  let rec traverse = (routeChild, ~ctx) => {
    switch routeChild {
    | RouteEntry(routeEntry) =>
      let fullRouteName = routeEntry.name->RouteName.getFullRouteName

      addLens(
        ~range=routeEntry.name->RouteName.getLoc->mapRangeFromStartOnly,
        ~command=LspProtocol.Command.makeTextOnlyCommand(fullRouteName),
      )

      addLens(
        ~range=routeEntry.path.loc->mapRangeFromStartOnly,
        ~command=LspProtocol.Command.makeTextOnlyCommand(
          routeEntry.routePath->RoutePath.getFullRoutePath,
        ),
      )

      routeEntry.children->Option.getWithDefault([])->traverseRouteChildren(~ctx)
    | _ => ()
    }
  }
  and traverseRouteChildren = (routeChildren, ~ctx) => {
    routeChildren->Array.forEach(child => child->traverse(~ctx))
  }

  let routeFileName = ctx.fileUri->toRouteFileName

  switch routeStructure.routeFiles->Dict.get(routeFileName) {
  | None => ()
  | Some({content}) => content->traverseRouteChildren(~ctx)
  }

  switch lenses->Array.length {
  | 0 => None
  | _ => Some(lenses)
  }
}

let routeRendererCodeLens = (
  routeStructure: routeStructure,
  ~routeRendererFileName,
  ~routeRendererFileContent,
  ~ctx: lspResolveContext,
): option<array<LspProtocol.codeLens>> => {
  let lines = routeRendererFileContent->String.split("\n")
  let foundRenderer = ref(None)

  for lineIdx in 0 to lines->Array.length - 1 {
    switch foundRenderer.contents {
    | Some(_) => ()
    | None =>
      let line = lines->Array.getUnsafe(lineIdx)
      if line->String.includes("makeRenderer(") {
        let characterStart = line->String.indexOf("makeRenderer(")
        let characterEnd = line->String.length

        let range: LspProtocol.range = {
          start: {
            line: lineIdx,
            character: characterStart,
          },
          end_: {
            line: lineIdx,
            character: characterEnd,
          },
        }

        // Now let's find the target route so we can open that file via the code
        // lens.
        let routeName = LspUtils.routeNameFromRouteRendererFileName(routeRendererFileName)

        switch routeName->Belt.Option.flatMap(routeName =>
          routeName->LspUtils.findRouteWithName(~routeChildren=routeStructure.result)
        ) {
        | None => ()
        | Some(routeEntry) =>
          foundRenderer :=
            Some(
              LspProtocol.makeCodeLensItem(
                ~range,
                ~command=LspProtocol.Command.makeOpenFileAtPosCommand(
                  ~pos=routeEntry.loc.start->mapPos,
                  ~title=`Open route definition`,
                  ~fileUri=Utils.pathInRoutesFolder(
                    ~fileName=routeEntry.sourceFile,
                    ~config=ctx.config,
                  ),
                ),
              ),
            )
        }
      }
    }
  }

  switch foundRenderer.contents {
  | None => None
  | Some(rendererCodeLens) => Some([rendererCodeLens])
  }
}

let documentLinks = (routeStructure: routeStructure, ~ctx: lspResolveContext): option<
  array<LspProtocol.documentLink>,
> => {
  let documentLinks: array<LspProtocol.documentLink> = []

  @live
  let addDocumentLink = (~range, ~fileUri, ~tooltip=?) => {
    documentLinks->Array.push(LspProtocol.makeDocumentLink(~range, ~fileUri, ~tooltip?))
  }

  let rec traverse = (routeChild, ~ctx: lspResolveContext) => {
    switch routeChild {
    | RouteEntry(routeEntry) =>
      addDocumentLink(
        ~range=routeEntry.name->RouteName.getLoc->mapRange,
        ~fileUri=Utils.pathInRoutesFolder(
          ~config=ctx.config,
          ~fileName=routeEntry.name->RouteName.getRouteRendererFileName,
        ),
        ~tooltip=`Open route renderer`,
      )

      routeEntry.children->Option.getWithDefault([])->traverseRouteChildren(~ctx)

    | Include(includeEntry) =>
      if ctx.routeFileNames->Array.includes(includeEntry.fileName.text) {
        addDocumentLink(
          ~range=includeEntry.fileName.loc->mapRange,
          ~fileUri=Utils.pathInRoutesFolder(
            ~config=ctx.config,
            ~fileName=includeEntry.fileName.text,
          ),
          ~tooltip=`Open file`,
        )
      }
    }
  }
  and traverseRouteChildren = (routeChildren, ~ctx) => {
    routeChildren->Array.forEach(child => child->traverse(~ctx))
  }

  let routeFileName = ctx.fileUri->toRouteFileName

  switch routeStructure.routeFiles->Dict.get(routeFileName) {
  | None => ()
  | Some({content}) => content->traverseRouteChildren(~ctx)
  }

  switch documentLinks->Array.length {
  | 0 => None
  | _ => Some(documentLinks)
  }
}

let diagnostics = (errors: array<decodeError>): array<(string, array<LspProtocol.diagnostic>)> => {
  let diagnosticsPerFile = Dict.make()

  errors->Array.forEach(error => {
    let targetDiagnosticsArray = switch diagnosticsPerFile->Dict.get(error.routeFileName) {
    | Some(diagnosticsArray) => diagnosticsArray
    | None =>
      let diagnosticsArray = []
      diagnosticsPerFile->Dict.set(error.routeFileName, diagnosticsArray)
      diagnosticsArray
    }

    let _ =
      targetDiagnosticsArray->Array.push(
        LspProtocol.makeDiagnostic(~message=error.message, ~range=error.loc->mapRange),
      )
  })

  diagnosticsPerFile->Dict.toArray
}
