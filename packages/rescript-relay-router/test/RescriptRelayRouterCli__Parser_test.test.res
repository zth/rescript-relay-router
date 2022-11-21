open RescriptRelayRouterCli__Types
open Vitest
module P = RescriptRelayRouterCli__Parser
module Bindings = RescriptRelayRouterCli__Bindings

let makeMockParserCtx = (
  ~content,
  ~routeFileName="routes.json",
  ~routeFiles=Dict.empty(),
  (),
): P.currentFileContext => {
  let lineLookup = Bindings.LinesAndColumns.make(content)

  {
    routeFileName,
    lineLookup,
    addDecodeError: (~loc as _, ~message as _) => {
      ()
    },
    getRouteFile: (~fileName, ~parentContext as _) =>
      switch routeFiles->Js.Dict.get(fileName) {
      | None => Error("Route file not mocked.")
      | Some(rawText) => Ok({content: [], fileName, rawText})
      },
  }
}

describe("Parsing", () => {
  test("path params are inherited from parent routes", _t => {
    let mockContent = `[
    {
        "name": "Organization", 
        "path": "/o/:slug",
        "children": [
            {
                "name": "Member",
                "path": "member/:memberId"
            }
        ]
    }
]`
    let ctx = makeMockParserCtx(~content=mockContent, ())
    let parentContext = P.emptyParentCtx(~routesByName=Dict.empty())

    let parsed =
      mockContent
      ->JsoncParser.parse([], ())
      ->Option.flatMap(node => node->P.ReScriptTransformer.transformNode(~ctx))

    let routes = parsed->P.Decode.decode(~ctx, ~parentContext)

    suite->assertions(2)

    switch routes {
    | [
        RouteEntry({
          pathParams: pathParamsParent,
          children: Some([RouteEntry({pathParams: pathParamsChild})]),
        }),
      ] =>
      expect(
        pathParamsParent->Array.map(
          p =>
            switch p {
            | PathParam({text}) => text
            | PathParamWithMatchBranches({text}, _) => text
            },
        ),
      )->Expect.toEqual(["slug"])

      expect(
        pathParamsChild->Array.map(
          p =>
            switch p {
            | PathParam({text}) => text
            | PathParamWithMatchBranches({text}, _) => text
            },
        ),
      )->Expect.toEqual(["memberId", "slug"])
    | _ => ()
    }
  })
})
