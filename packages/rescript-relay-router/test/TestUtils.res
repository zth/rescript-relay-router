open RescriptRelayRouterCli__Types

module P = RescriptRelayRouterCli__Parser
module U = RescriptRelayRouterCli__Utils

let parseMockContent = mockContent => {
  let decodeErrors = []
  let routeFiles = Dict.empty()
  let routesByName = Dict.empty()

  "routes.json"->P.parseRouteFile(
    ~config={
      generatedPath: "",
      routesFolderPath: "",
      rescriptLibFolderPath: "",
    },
    ~decodeErrors,
    ~parentContext=P.emptyParentCtx(~routesByName),
    ~parserContext={
      routeFiles,
      routeFileNames: ["routes.json"],
      getRouteFileContents: _ => Ok(mockContent),
    },
  )
}

let testMatchLocation = (mockContent, pathname) => {
  let {result} = parseMockContent(mockContent)

  let cliMatchableRoutes = result->U.routeChildrenToPrintable->Array.map(U.rawRouteToMatchable)

  cliMatchableRoutes->U.matchRoutesCli({
    "pathname": pathname,
    "search": "",
    "hash": "",
    "state": Js.Json.null,
  })
}
