open Vitest

module P = RescriptRelayRouterCli__Parser
module U = RescriptRelayRouterCli__Utils
module Bindings = RescriptRelayRouterCli__Bindings

describe("ReactRouter modifications", () => {
  test("enumeration-via-regex matching works", _t => {
    let mockRoute = `[{
      "name": "Organization",
      "path": "/o/:slug/member/:status(online|offline|idle)"
    }]`

    // Should match via regexp
    mockRoute
    ->TestUtils.testMatchLocation("/o/test/member/online")
    ->Option.getWithDefault([])
    ->Array.length
    ->expect
    ->Expect.toBe(1)

    // Is not in enumeration, should not match
    mockRoute
    ->TestUtils.testMatchLocation("/o/test/member/something")
    ->Option.getWithDefault([])
    ->Array.length
    ->expect
    ->Expect.toBe(0)
  })
})
