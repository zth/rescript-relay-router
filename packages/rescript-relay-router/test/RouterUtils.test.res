open RescriptRelayRouterTestUtils.Vitest
open RelayRouter__Utils

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
