open RescriptRelayRouterTestUtils
open Vitest

let locationFromPath = pathname =>
  RelayRouter.History.createMemoryHistory(
    ~options={"initialEntries": [pathname]},
  )->RelayRouter.History.getLocation

describe("getActiveSubRoute", () => {
  test("returns Home for a static direct child route", _t => {
    switch Routes.Root.Route.getActiveSubRoute(locationFromPath("/home")) {
    | Some(#Home) => expect(true)->Expect.toBe(true)
    | _ => expect(false)->Expect.toBe(true)
    }
  })

  test("returns PathParamsOnly for a direct child route with path params", _t => {
    switch Routes.Root.Route.getActiveSubRoute(locationFromPath("/other/acme")) {
    | Some(#PathParamsOnly) => expect(true)->Expect.toBe(true)
    | _ => expect(false)->Expect.toBe(true)
    }
  })

  test("returns ByStatusDecodedExtra for a direct child route spanning multiple segments", _t => {
    switch Routes.Root.Todos.Route.getActiveSubRoute(locationFromPath("/todos/extra/completed")) {
    | Some(#ByStatusDecodedExtra) => expect(true)->Expect.toBe(true)
    | _ => expect(false)->Expect.toBe(true)
    }
  })
})
