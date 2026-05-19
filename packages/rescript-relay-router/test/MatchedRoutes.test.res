open RescriptRelayRouterTestUtils.Vitest

let render = (~childRoutes as _) => React.null

let makeRoute = (~name, ~slots=[], ~outlet=?, ()): RelayRouter.Types.route => {
  path: "",
  name,
  slots,
  outlet,
  loadRouteRenderer: () => Promise.resolve(),
  preloadCode: (~environment as _, ~pathParams as _, ~queryParams as _, ~location as _) =>
    Promise.resolve([]),
  prepare: (
    ~environment as _,
    ~pathParams as _,
    ~queryParams as _,
    ~location as _,
    ~intent as _,
  ) => {
    routeKey: `${name}:prepared`,
    render,
  },
  children: [],
}

describe("matched route snapshots", () => {
  test("copies route identity, prepared route key, params, slots, and outlet", _t => {
    let shellRoute = makeRoute(~name="Shell", ~slots=["Overlay"], ())
    let threadRoute = makeRoute(~name="Shell__Workspace__Thread", ~outlet="Overlay", ())
    let matches: array<RelayRouter.Types.routeMatch> = [
      {
        route: shellRoute,
        params: dict{
          "workspaceSlug": "default",
        },
      },
      {
        route: threadRoute,
        params: dict{
          "workspaceSlug": "default",
          "channelSlug": "general",
          "threadId": "t1",
        },
      },
    ]
    let preparedMatches: array<RelayRouter.Types.preparedMatch> = [
      {
        routeKey: "Shell:default",
        routeName: "Shell",
        slots: ["Overlay"],
        outlet: None,
        render,
      },
      {
        routeKey: "Thread:default:general:t1",
        routeName: "Shell__Workspace__Thread",
        slots: [],
        outlet: Some("Overlay"),
        render,
      },
    ]

    let matchedRoutes = matches->RelayRouter__MatchedRoutes.make(preparedMatches)
    expect(matchedRoutes->Array.length)->Expect.toBe(2)

    switch matchedRoutes->Array.get(1) {
    | Some(matchedRoute) =>
      expect(matchedRoute.routeName)->Expect.toBe("Shell__Workspace__Thread")
      expect(matchedRoute.routeKey)->Expect.toBe("Thread:default:general:t1")
      expect(matchedRoute.outlet)->Expect.toBe(Some("Overlay"))
      expect(matchedRoute.pathParams->Dict.get("workspaceSlug"))->Expect.toBe(Some("default"))
      expect(matchedRoute.pathParams->Dict.get("channelSlug"))->Expect.toBe(Some("general"))
      expect(matchedRoute.pathParams->Dict.get("threadId"))->Expect.toBe(Some("t1"))
    | None => expect("missing matched route")->Expect.toBe("matched route")
    }
  })

  test("falls back to the route name when there is no prepared match", _t => {
    let matches: array<RelayRouter.Types.routeMatch> = [
      {
        route: makeRoute(~name="Shell", ()),
        params: dict{},
      },
    ]

    switch matches->RelayRouter__MatchedRoutes.make([])->Array.get(0) {
    | Some(matchedRoute) => expect(matchedRoute.routeKey)->Expect.toBe("Shell")
    | None => expect("missing matched route")->Expect.toBe("matched route")
    }
  })
})
