open RescriptRelayRouterTestUtils.Vitest

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

let render = (~childRoutes as _) => React.null

let makePreparedMatch = (~routeName, ~slots=[], ~outlet=?, ()) => {
  RelayRouter__Types.routeKey: routeName,
  routeName,
  slots,
  outlet,
  render,
}

let routeNames = matches =>
  matches->Array.map(({RelayRouter__Types.routeName: routeName}) => routeName)

let renderElement = text =>
  (~childRoutes) =>
    <section>
      <span> {React.string(text)} </span>
      {childRoutes}
    </section>

let makeRoute = (~path, ~name, ~slots=[], ~outlet=?, ~effectiveOutlet=?, ~children=[], ()) => {
  RelayRouter__Types.path,
  name,
  slots,
  outlet,
  effectiveOutlet,
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
    routeKey: name,
    render,
  },
  children,
}

let renderShellWithOverlay = (~childRoutes) =>
  <section>
    <span> {React.string("shell")} </span>
    {childRoutes}
    <RelayRouter.Slot routeName="Shell" slotName="Overlay" />
  </section>

let testLocation =
  RelayRouter.History.createMemoryHistory(
    ~options={"initialEntries": ["/preferences/account"]},
  )->RelayRouter.History.getLocation

describe("RelayRouter__RouteSlots", () => {
  test("splits an outlet branch away from the primary route branch", _t => {
    let matches = [
      makePreparedMatch(~routeName="Shell", ~slots=["Overlay"], ()),
      makePreparedMatch(~routeName="Preferences", ()),
      makePreparedMatch(~routeName="Account", ~outlet="Overlay", ()),
    ]

    let (primaryMatches, slotBranch) = matches->RelayRouter__RouteSlots.splitPreparedMatches

    expect(primaryMatches->routeNames)->Expect.toStrictEqual(["Shell"])

    switch slotBranch {
    | Some({hostRouteName, slotName, matches}) =>
      expect(hostRouteName)->Expect.toBe("Shell")
      expect(slotName)->Expect.toBe("Overlay")
      expect(matches->routeNames)->Expect.toStrictEqual(["Preferences", "Account"])
    | None => expect("missing slot branch")->Expect.toBe("slot branch")
    }
  })

  test("uses the nearest ancestor that declares the outlet slot", _t => {
    let matches = [
      makePreparedMatch(~routeName="Shell", ~slots=["Overlay"], ()),
      makePreparedMatch(~routeName="Workspace", ~slots=["Overlay"], ()),
      makePreparedMatch(~routeName="Preferences", ()),
      makePreparedMatch(~routeName="Account", ~outlet="Overlay", ()),
    ]

    let (primaryMatches, slotBranch) = matches->RelayRouter__RouteSlots.splitPreparedMatches

    expect(primaryMatches->routeNames)->Expect.toStrictEqual(["Shell", "Workspace"])

    switch slotBranch {
    | Some({hostRouteName, slotName, matches}) =>
      expect(hostRouteName)->Expect.toBe("Workspace")
      expect(slotName)->Expect.toBe("Overlay")
      expect(matches->routeNames)->Expect.toStrictEqual(["Preferences", "Account"])
    | None => expect("missing slot branch")->Expect.toBe("slot branch")
    }
  })

  test("leaves all matches primary when no ancestor declares the outlet slot", _t => {
    let matches = [
      makePreparedMatch(~routeName="Shell", ()),
      makePreparedMatch(~routeName="Preferences", ~outlet="Overlay", ()),
    ]

    let (primaryMatches, slotBranch) = matches->RelayRouter__RouteSlots.splitPreparedMatches

    expect(primaryMatches->routeNames)->Expect.toStrictEqual(["Shell", "Preferences"])

    switch slotBranch {
    | Some(_) => expect("unexpected slot branch")->Expect.toBe("no slot branch")
    | None => expect(true)->Expect.toBe(true)
    }
  })

  test("builds route entries with primary matches and keyed slot content", _t => {
    let matches = [
      makePreparedMatch(~routeName="Shell", ~slots=["Overlay"], ()),
      makePreparedMatch(~routeName="Preferences", ()),
      makePreparedMatch(~routeName="Account", ~outlet="Overlay", ()),
    ]

    let routeEntry =
      matches->RelayRouter__RouteSlots.routeSetFromPreparedMatches(~location=testLocation)

    expect(routeEntry.primaryMatches->routeNames)->Expect.toStrictEqual(["Shell"])
    expect(routeEntry.allMatches->routeNames)->Expect.toStrictEqual([
      "Shell",
      "Preferences",
      "Account",
    ])
    expect(
      routeEntry.slotContents
      ->Dict.get(RelayRouter__RouteSlots.slotKey(~routeName="Shell", ~slotName="Overlay"))
      ->Option.isSome,
    )->Expect.toBe(true)
    expect(
      routeEntry.slotContents
      ->Dict.get(RelayRouter__RouteSlots.slotKey(~routeName="Preferences", ~slotName="Overlay"))
      ->Option.isSome,
    )->Expect.toBe(false)
  })

  test("renders keyed slot content through RouteRenderer", _t => {
    let matches = [
      {
        ...makePreparedMatch(~routeName="Shell", ~slots=["Overlay"], ()),
        render: renderShellWithOverlay,
      },
      {...makePreparedMatch(~routeName="Preferences", ()), render: renderElement("preferences")},
      {
        ...makePreparedMatch(~routeName="Account", ~outlet="Overlay", ()),
        render: renderElement("account"),
      },
    ]

    let routeEntry =
      matches->RelayRouter__RouteSlots.routeSetFromPreparedMatches(~location=testLocation)
    let routerContext: RelayRouter.Types.routerContext = {
      preload: (~priority=?, _url) => ignore(priority),
      preloadCode: (~priority=?, _url) => ignore(priority),
      preloadAsset: (~priority, _asset) => ignore(priority),
      get: () => routeEntry,
      subscribe: _callback => () => (),
      getLocation: () => routeEntry.location,
      subscribeToLocation: _callback => () => (),
      history: RelayRouter.History.createMemoryHistory(
        ~options={"initialEntries": ["/preferences/account"]},
      ),
      subscribeToEvent: _callback => () => (),
      postRouterEvent: _event => (),
      markNextNavigationAsShallow: () => (),
    }

    let html = <RelayRouter.Provider value={routerContext}>
      <RelayRouter.RouteRenderer />
    </RelayRouter.Provider>->renderToStaticMarkup

    expect(html)->Expect.String.toContain("shell")
    expect(html)->Expect.String.toContain("preferences")
    expect(html)->Expect.String.toContain("account")
  })
})

describe("RelayRouter.Internal.outletForUrl", () => {
  test("returns the deepest match effective outlet", _t => {
    let routes = [
      makeRoute(
        ~path="/",
        ~name="Root",
        ~slots=["Overlay"],
        ~children=[
          makeRoute(
            ~path="settings",
            ~name="Settings",
            ~outlet="Overlay",
            ~effectiveOutlet="Overlay",
            ~children=[makeRoute(~path="account", ~name="Account", ~effectiveOutlet="Overlay", ())],
            (),
          ),
          makeRoute(~path="todos", ~name="Todos", ()),
        ],
        (),
      ),
    ]

    let compiledRoutes = routes->RelayRouter.Internal.compileRoutes

    expect(
      RelayRouter.Internal.outletForUrl(compiledRoutes, "/settings/account?tab=profile"),
    )->Expect.toBe(Some("Overlay"))
    expect(RelayRouter.Internal.outletForUrl(compiledRoutes, "settings/account"))->Expect.toBe(
      Some("Overlay"),
    )
    expect(RelayRouter.Internal.outletForUrl(compiledRoutes, "/todos"))->Expect.toBe(None)
    expect(RelayRouter.Internal.outletForUrl(compiledRoutes, "/missing"))->Expect.toBe(None)
  })
})
