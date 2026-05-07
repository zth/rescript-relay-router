open RescriptRelayRouterTestUtils.Vitest
open RelayRouter__Utils

module SlotComponentCompileFixture = {
  @react.component
  let make = (~fallback=?) => <RelayRouter.Slot routeName="Root" slotName="Overlay" ?fallback />
}

type testCase = {
  exact: bool,
  pathname: string,
  routePattern: string,
  expected: bool,
}

describe("RelayRouter__Utils", () => {
  describe("isRouteActive", () => {
    let testCases = [
      {
        exact: false,
        pathname: "/some/path/123",
        routePattern: "/",
        expected: true,
      },
      {
        exact: true,
        pathname: "/some/path/123",
        routePattern: "/",
        expected: false,
      },
      {
        exact: true,
        pathname: "/",
        routePattern: "/",
        expected: true,
      },
      {
        exact: false,
        pathname: "/some/path/123",
        routePattern: "/some/path/:id",
        expected: true,
      },
      {
        exact: true,
        pathname: "/some/path/123",
        routePattern: "/some/path/:id",
        expected: true,
      },
      {
        exact: false,
        pathname: "/some/path/123/subroute",
        routePattern: "/some/path/:id",
        expected: true,
      },
      {
        exact: true,
        pathname: "/some/path/123/subroute",
        routePattern: "/some/path/:id",
        expected: false,
      },
    ]

    testCases->Array.forEach(
      ({exact, pathname, routePattern, expected}) => {
        test(
          `pattern: "${routePattern}", path: "${pathname}", exact: ${exact ? "true" : "false"}`,
          _t => {
            expect(isRouteActive(~exact, ~pathname, ~routePattern))->Expect.toBe(expected)
          },
        )
      },
    )
  })
})

describe("RelayRouter__Internal.RouteKey", () => {
  test("distinguishes adjacent path param values that concatenate to the same string", _t => {
    let key1 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addPathParam(~name="first", ~value="a")
      ->RelayRouter__Internal.RouteKey.addPathParam(~name="second", ~value="bc")

    let key2 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addPathParam(~name="first", ~value="ab")
      ->RelayRouter__Internal.RouteKey.addPathParam(~name="second", ~value="c")

    expect(key1 === key2)->Expect.toBe(false)
  })

  test("distinguishes path param field names", _t => {
    let key1 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addPathParam(~name="first", ~value="same")

    let key2 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addPathParam(~name="second", ~value="same")

    expect(key1 === key2)->Expect.toBe(false)
  })

  test("distinguishes missing query params from empty query params", _t => {
    let key1 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addQueryParam(~name="first", ~value=None)

    let key2 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addQueryParam(~name="first", ~value=Some(""))

    expect(key1 === key2)->Expect.toBe(false)
  })

  test("distinguishes scalar query param field names", _t => {
    let key1 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addQueryParam(~name="first", ~value=Some("same"))

    let key2 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addQueryParam(~name="second", ~value=Some("same"))

    expect(key1 === key2)->Expect.toBe(false)
  })

  test("distinguishes repeated query param value boundaries", _t => {
    let key1 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addQueryParamArray(~name="tags", ~values=Some(["a", "bc"]))

    let key2 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addQueryParamArray(~name="tags", ~values=Some(["ab", "c"]))

    expect(key1 === key2)->Expect.toBe(false)
  })

  test("preserves repeated query param order", _t => {
    let key1 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addQueryParamArray(~name="tags", ~values=Some(["a", "b"]))

    let key2 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addQueryParamArray(~name="tags", ~values=Some(["b", "a"]))

    expect(key1 === key2)->Expect.toBe(false)
  })

  test("distinguishes missing repeated query params from present empty arrays", _t => {
    let key1 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addQueryParamArray(~name="tags", ~values=None)

    let key2 =
      RelayRouter__Internal.RouteKey.make("Root")
      ->RelayRouter__Internal.RouteKey.addQueryParamArray(~name="tags", ~values=Some([]))

    expect(key1 === key2)->Expect.toBe(false)
  })
})
