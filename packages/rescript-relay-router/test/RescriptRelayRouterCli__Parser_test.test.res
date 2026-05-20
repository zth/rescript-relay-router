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

  test("parses route slots and descendant outlets", _t => {
    let {errors, result} = parseRouteStructure(`[
      {
        "name": "Shell",
        "path": "/",
        "slots": [{ "name": "Overlay" }],
        "children": [
          {
            "name": "Preferences",
            "path": "preferences",
            "children": [
              {
                "name": "Account",
                "path": "account",
                "outlet": "Overlay"
              }
            ]
          }
        ]
      }
    ]`)

    suite->assertions(3)
    expect(errors)->Expect.Array.toHaveLength(0)
    switch result {
    | [
        RouteEntry({
          slots,
          children: Some([RouteEntry({children: Some([RouteEntry({outlet: Some(outlet)})])})]),
        }),
      ] =>
      expect(slots->Array.map(slot => slot.name.text))->Expect.toEqual(["Overlay"])
      expect(outlet.text)->Expect.toBe("Overlay")
    | _ => ()
    }
  })

  test("allows entrypoint on top-level routes", _t => {
    let {errors, result} = parseRouteStructure(`[
      {
        "name": "Admin",
        "path": "/admin",
        "entrypoint": true
      }
    ]`)

    suite->assertions(2)
    expect(errors)->Expect.Array.toHaveLength(0)
    switch result {
    | [RouteEntry({entrypoint})] => expect(entrypoint)->Expect.toBe(true)
    | _ => ()
    }
  })

  test("reports outlets without ancestor slot declarations", _t => {
    let {errors} = parseRouteStructure(`[
      {
        "name": "Root",
        "path": "/",
        "children": [
          {
            "name": "Preferences",
            "path": "preferences",
            "outlet": "Overlay"
          }
        ]
      }
    ]`)

    expect(
      errors->Array.map(error => error.message),
    )->Expect.Array.toContain(`Outlet "Overlay" does not match a slot declared by an ancestor route.`)
  })

  test("reports entrypoint on nested routes", _t => {
    let {errors} = parseRouteStructure(`[
      {
        "name": "Root",
        "path": "/",
        "children": [
          {
            "name": "Settings",
            "path": "settings",
            "entrypoint": true
          }
        ]
      }
    ]`)

    expect(
      errors->Array.map(error => error.message),
    )->Expect.Array.toContain(`"entrypoint" can only be used on top-level routes.`)
  })

  test("reports non-boolean entrypoint values", _t => {
    let {errors} = parseRouteStructure(`[
      {
        "name": "Admin",
        "path": "/admin",
        "entrypoint": "true"
      }
    ]`)

    expect(
      errors->Array.map(error => error.message),
    )->Expect.Array.toContain(`"entrypoint" needs to be a boolean. Found string("true").`)
  })

  test("reports top-level route names that shadow the router runtime module", _t => {
    let {errors} = parseRouteStructure(`[
      {
        "name": "RelayRouter",
        "path": "/router"
      }
    ]`)

    expect(
      errors->Array.map(error => error.message),
    )->Expect.Array.toContain(`"RelayRouter" cannot be used as a top-level route name because it would shadow the router runtime module in generated route declarations.`)
  })
})
