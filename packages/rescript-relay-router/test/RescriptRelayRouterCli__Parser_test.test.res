open RescriptRelayRouterCli__Types
open RescriptRelayRouterTestUtils.Vitest
module P = RescriptRelayRouterCli__Parser
module Bindings = RescriptRelayRouterCli__Bindings

let parseRouteStructure = mockContent =>
  P.readRouteStructure(
    ~config={
      generatedPath: "",
      routesFolderPath: "",
      rescriptLibFolderPath: "",
    },
    ~getRouteFileContents=_ => Ok(mockContent),
  )

let makeMockParserCtx = (
  ~content,
  ~routeFileName="routes.json",
  ~routeFiles=Dict.make(),
): P.currentFileContext => {
  let lineLookup = Bindings.LinesAndColumns.make(content)

  {
    routeFileName,
    lineLookup,
    addDecodeError: (~loc as _, ~message as _) => {
      ()
    },
    getRouteFile: (~fileName, ~parentContext as _) =>
      switch routeFiles->Dict.get(fileName) {
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
    let ctx = makeMockParserCtx(~content=mockContent)
    let parentContext = P.emptyParentCtx(~routesByName=Dict.make())

    let parsed =
      mockContent
      ->JsoncParser.parse([])
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
            | PathParam({text})
            | PathParamWithMatchBranches({text}) =>
              text.text
            },
        ),
      )->Expect.toEqual(["slug"])

      expect(
        pathParamsChild->Array.map(
          p =>
            switch p {
            | PathParam({text})
            | PathParamWithMatchBranches({text}) =>
              text.text
            },
        ),
      )->Expect.toEqual(["memberId", "slug"])
    | _ => ()
    }
  })

  test("allows separatelyRenderable on top-level routes", _t => {
    let {errors, result} = parseRouteStructure(`[
      {
        "name": "Admin",
        "path": "/admin",
        "separatelyRenderable": true
      }
    ]`)

    suite->assertions(2)
    expect(errors)->Expect.Array.toHaveLength(0)
    switch result {
    | [RouteEntry({separatelyRenderable})] => expect(separatelyRenderable)->Expect.toBe(true)
    | _ => ()
    }
  })

  test("reports separatelyRenderable on nested routes", _t => {
    let {errors} = parseRouteStructure(`[
      {
        "name": "Root",
        "path": "/",
        "children": [
          {
            "name": "Settings",
            "path": "settings",
            "separatelyRenderable": true
          }
        ]
      }
    ]`)

    expect(errors->Array.map(error => error.message))->Expect.Array.toContain(
      `"separatelyRenderable" can only be used on top-level routes.`,
    )
  })

  test("reports non-boolean separatelyRenderable values", _t => {
    let {errors} = parseRouteStructure(`[
      {
        "name": "Admin",
        "path": "/admin",
        "separatelyRenderable": "true"
      }
    ]`)

    expect(errors->Array.map(error => error.message))->Expect.Array.toContain(
      `"separatelyRenderable" needs to be a boolean. Found string("true").`,
    )
  })
})
