open RescriptRelayRouterCli__Types
open Vitest
module P = RescriptRelayRouterCli__Parser
module Bindings = RescriptRelayRouterCli__Bindings

let makeMockParserCtx = (
  ~content,
  ~routeFileName="routes.json",
  ~routeFiles=Js.Dict.empty(),
  (),
): P.currentFileContext => {
  let lineLookup = Bindings.LinesAndColumns.make(content)

  {
    routeFileName: routeFileName,
    lineLookup: lineLookup,
    addDecodeError: (~loc as _, ~message as _) => {
      ()
    },
    getRouteFile: (~fileName, ~parentContext as _) =>
      switch routeFiles->Js.Dict.get(fileName) {
      | None => Error("Route file not mocked.")
      | Some(rawText) => Ok({content: [], fileName: fileName, rawText: rawText})
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
    let parentContext = P.emptyParentCtx()

    let parsed =
      mockContent
      ->JsoncParser.parse([], ())
      ->Belt.Option.flatMap(node => node->P.ReScriptTransformer.transformNode(~ctx))

    let routes = parsed->P.Decode.decode(~ctx, ~parentContext)

    ExpectObj.expect->ExpectObj.assertions(2)

    switch routes {
    | [
        RouteEntry({
          pathParams: pathParamsParent,
          children: Some([RouteEntry({pathParams: pathParamsChild})]),
        }),
      ] =>
      expect(pathParamsParent->Belt.Array.map(({text}) => text))->Expect.toEqual(["slug"])
      expect(pathParamsChild->Belt.Array.map(({text}) => text))->Expect.toEqual([
        "memberId",
        "slug",
      ])
    | _ => ()
    }
  })
})
