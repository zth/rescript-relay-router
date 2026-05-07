import { describe, expect, test } from "vitest";
import {
  compileRoutes,
  matchCompiledRoutes,
  matchRoutes,
} from "../src/vendor/react-router.js";

const makeLocation = (pathname) => ({
  pathname,
  search: "",
  hash: "",
  state: null,
  key: "test",
});

describe("compiled route matching", () => {
  const routes = [
    {
      id: "root",
      path: "/",
      children: [
        { id: "teams", path: "teams" },
        { id: "team", path: "teams/:teamId" },
        {
          id: "member",
          path: "teams/:teamId/members/:memberStatus(active|inactive)",
        },
        { id: "files", path: "files/*" },
      ],
    },
    { id: "settings", path: "/settings" },
  ];

  const serializeMatches = (matches) =>
    matches?.map((match) => ({
      id: match.route.id,
      params: { ...match.params },
      pathname: match.pathname,
      pathnameBase: match.pathnameBase,
    })) ?? null;

  test("reproduces repeated route-tree walking in the matchRoutes compatibility path", () => {
    let childrenReads = 0;
    const leafRoutes = [
      { path: "teams/:teamId" },
      { path: "teams/:teamId/members/:memberId(active|inactive)" },
      { path: "files/*" },
    ];
    const routes = [
      {
        path: "/",
        get children() {
          childrenReads += 1;
          return leafRoutes;
        },
      },
    ];

    expect(matchRoutes(routes, makeLocation("/teams/core"))).toHaveLength(2);
    const readsAfterFirstMatch = childrenReads;

    expect(matchRoutes(routes, makeLocation("/teams/core/members/active"))).toHaveLength(2);
    expect(matchRoutes(routes, makeLocation("/files/a/b/c"))).toHaveLength(2);

    expect(childrenReads).toBeGreaterThan(readsAfterFirstMatch);
  });

  test.each([
    [
      "/",
      "root route",
      [{ id: "root", params: {}, pathname: "/", pathnameBase: "/" }],
    ],
    [
      "/teams",
      "nested static route",
      [
        { id: "root", params: {}, pathname: "/", pathnameBase: "/" },
        { id: "teams", params: {}, pathname: "/teams", pathnameBase: "/teams" },
      ],
    ],
    [
      "/teams/core",
      "dynamic param route",
      [
        {
          id: "root",
          params: { teamId: "core" },
          pathname: "/",
          pathnameBase: "/",
        },
        {
          id: "team",
          params: { teamId: "core" },
          pathname: "/teams/core",
          pathnameBase: "/teams/core",
        },
      ],
    ],
    [
      "/teams/core/members/active",
      "regex path param route",
      [
        {
          id: "root",
          params: { teamId: "core", memberStatus: "active" },
          pathname: "/",
          pathnameBase: "/",
        },
        {
          id: "member",
          params: { teamId: "core", memberStatus: "active" },
          pathname: "/teams/core/members/active",
          pathnameBase: "/teams/core/members/active",
        },
      ],
    ],
    [
      "/teams/core/members/inactive",
      "second regex path param branch",
      [
        {
          id: "root",
          params: { teamId: "core", memberStatus: "inactive" },
          pathname: "/",
          pathnameBase: "/",
        },
        {
          id: "member",
          params: { teamId: "core", memberStatus: "inactive" },
          pathname: "/teams/core/members/inactive",
          pathnameBase: "/teams/core/members/inactive",
        },
      ],
    ],
    ["/teams/core/members/pending", "unmatched regex path param route", null],
    [
      "/files/a/b/c",
      "splat route",
      [
        {
          id: "root",
          params: { "*": "a/b/c" },
          pathname: "/",
          pathnameBase: "/",
        },
        {
          id: "files",
          params: { "*": "a/b/c" },
          pathname: "/files/a/b/c",
          pathnameBase: "/files",
        },
      ],
    ],
    [
      "/settings/",
      "trailing slash",
      [
        {
          id: "settings",
          params: {},
          pathname: "/settings/",
          pathnameBase: "/settings",
        },
      ],
    ],
    ["/missing", "unmatched route", null],
  ])("matches expected output for %s (%s)", (pathname, _, expected) => {
    const compiledRoutes = compileRoutes(routes);

    expect(
      serializeMatches(matchCompiledRoutes(compiledRoutes, makeLocation(pathname)))
    ).toEqual(expected);
  });

  test("keeps matchRoutes as a compatibility wrapper", () => {
    const compiledRoutes = compileRoutes(routes);

    expect(
      serializeMatches(matchCompiledRoutes(compiledRoutes, makeLocation("/teams/core")))
    ).toEqual(serializeMatches(matchRoutes(routes, makeLocation("/teams/core"))));
  });

  test("preserves matched route object identity", () => {
    const compiledRoutes = compileRoutes(routes);
    const matches = matchCompiledRoutes(compiledRoutes, makeLocation("/teams/core"));

    expect(matches).toHaveLength(2);
    expect(matches[0].route).toBe(routes[0]);
    expect(matches[1].route).toBe(routes[0].children[1]);
  });

  test("compiled matching does not re-walk the route tree", () => {
    let childrenReads = 0;
    const leafRoutes = [
      { path: "teams/:teamId" },
      { path: "teams/:teamId/members/:memberId(active|inactive)" },
      { path: "files/*" },
    ];
    const routes = [
      {
        path: "/",
        get children() {
          childrenReads += 1;
          return leafRoutes;
        },
      },
    ];

    const compiledRoutes = compileRoutes(routes);
    const readsAfterCompile = childrenReads;

    expect(matchCompiledRoutes(compiledRoutes, makeLocation("/teams/core"))).toHaveLength(2);
    expect(matchCompiledRoutes(compiledRoutes, makeLocation("/teams/core/members/active"))).toHaveLength(2);
    expect(matchCompiledRoutes(compiledRoutes, makeLocation("/files/a/b/c"))).toHaveLength(2);

    expect(childrenReads).toBe(readsAfterCompile);
  });
});
