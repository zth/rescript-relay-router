open RescriptRelayRouterTestUtils.Vitest
open RescriptRelayRouterCli__Types

module U = RescriptRelayRouterCli__Utils
module DumpRoutes = RescriptRelayRouterCli__DumpRoutes
module Bindings = RescriptRelayRouterCli__Bindings

@module("os") external tmpdir: unit => string = "tmpdir"
@module("fs") external mkdtempSync: string => string = "mkdtempSync"
@module("fs")
external mkdirRecursiveSync: (string, @as(json`{"recursive":true}`) _) => unit = "mkdirSync"
@module("fs") external writeFileSync: (string, string) => unit = "writeFileSync"
@module("fs") external readFileSync: (string, @as(json`"utf-8"`) _) => string = "readFileSync"
@module("fs")
external rmSync: (string, @as(json`{"recursive":true,"force":true}`) _) => unit = "rmSync"
@send external indexOfFrom: (string, string, int) => int = "indexOf"
@send external slice: (string, int, int) => string = "slice"

let stringifyDump = dumped =>
  dumped->Array.map(route => JSON.Object(route))->JSON.Array->JSON.stringify

let testConfig = {
  generatedPath: "src/routes/__generated__",
  routesFolderPath: "src/routes",
  rescriptLibFolderPath: "lib/bs",
}

let withGeneratedRoutes = (routesJson, callback) => {
  let rootPath = mkdtempSync(Bindings.Path.join([tmpdir(), "rrr-routes-"]))
  let routesFolderPath = Bindings.Path.join([rootPath, "routes"])
  let generatedPath = Bindings.Path.join([rootPath, "__generated__"])

  mkdirRecursiveSync(routesFolderPath)
  mkdirRecursiveSync(generatedPath)
  writeFileSync(Bindings.Path.join([routesFolderPath, "routes.json"]), routesJson)

  try {
    RescriptRelayRouterCli__Commands.generateRoutes(
      ~scaffoldAfter=false,
      ~deleteRemoved=false,
      ~config={
        generatedPath,
        routesFolderPath,
        rescriptLibFolderPath: Bindings.Path.join([rootPath, "lib", "bs"]),
      },
    )

    let result = callback(~generatedPath)
    rmSync(rootPath)
    result
  } catch {
  | exn =>
    rmSync(rootPath)
    throw(exn)
  }
}

let readGeneratedFile = (~generatedPath, ~fileName) =>
  readFileSync(Bindings.Path.join([generatedPath, fileName]))

let sliceBetween = (content, ~startMarker, ~endMarker) => {
  let start = content->String.indexOf(startMarker)
  let end_ = content->indexOfFrom(endMarker, start + startMarker->String.length)
  content->slice(start, end_)
}

let withSinglePrintableRoute = (routesJson, callback) => {
  let {result} = TestUtils.parseMockContent(routesJson)
  switch result->U.routeChildrenToPrintable {
  | [route] => callback(route)
  | routes => expect(routes->Array.length)->Expect.toBe(1)
  }
}

describe("Query params", () => {
  test("turns param type to string", _t => {
    open U.QueryParams

    expect(toTypeStr(String))->Expect.toBe("string")
    expect(toTypeStr(Boolean))->Expect.toBe("bool")
    expect(toTypeStr(Int))->Expect.toBe("int")
    expect(toTypeStr(Float))->Expect.toBe("float")
    expect(
      toTypeStr(CustomModule({moduleName: "SomeModule.SomeInnerModule", required: false})),
    )->Expect.toBe("SomeModule.SomeInnerModule.t")

    expect(toTypeStr(Array(String)))->Expect.toBe("array<string>")
    expect(toTypeStr(Array(Boolean)))->Expect.toBe("array<bool>")
    expect(toTypeStr(Array(Int)))->Expect.toBe("array<int>")
    expect(toTypeStr(Array(Float)))->Expect.toBe("array<float>")
    expect(
      toTypeStr(Array(CustomModule({moduleName: "SomeModule.SomeInnerModule", required: false}))),
    )->Expect.toBe("array<SomeModule.SomeInnerModule.t>")
  })

  test("serializes query param types", _t => {
    open U.QueryParams

    expect(String->toSerializer(~variableName="propName"))->Expect.toBe("propName")
    expect(
      Boolean->toSerializer(~variableName="propName"),
    )->Expect.toBe(`switch propName { | true => "true" | false => "false" }`)
    expect(Int->toSerializer(~variableName="propName"))->Expect.toBe("Int.toString(propName)")
    expect(Float->toSerializer(~variableName="propName"))->Expect.toBe("Float.toString(propName)")
    expect(
      CustomModule({moduleName: "SomeModule", required: false})->toSerializer(
        ~variableName="propName",
      ),
    )->Expect.toBe("propName->SomeModule.serialize")

    /* Arrays */
    expect(Array(String)->toSerializer(~variableName="propName"))->Expect.toBe("propName")
    expect(
      Array(Boolean)->toSerializer(~variableName="propName"),
    )->Expect.toBe(`propName->Array.map(bool => switch bool { | true => "true" | false => "false" })`)
    expect(Array(Int)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Array.map(Int.toString)",
    )
    expect(Array(Float)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Array.map(Float.toString)",
    )
    expect(
      Array(CustomModule({moduleName: "SomeModule", required: false}))->toSerializer(
        ~variableName="propName",
      ),
    )->Expect.toBe("propName->Array.map(value => value->SomeModule.serialize)")
  })

  test("emits parse code for query params", _t => {
    open U.QueryParams

    expect(String->toParser(~variableName="propName"))->Expect.toBe("Some(propName)")
    expect(Int->toParser(~variableName="propName"))->Expect.toBe("Int.fromString(propName)")
    expect(Float->toParser(~variableName="propName"))->Expect.toBe("Float.fromString(propName)")

    expect(
      CustomModule({moduleName: "SomeModule", required: false})->toParser(~variableName="propName"),
    )->Expect.toBe("propName->SomeModule.parse")

    expect(
      CustomModule({moduleName: "SomeModule", required: true})->toParser(~variableName="propName"),
    )->Expect.toBe("propName->SomeModule.parse")

    /* Arrays */
    expect(Array(String)->toParser(~variableName="propName"))->Expect.toBe("propName")
    expect(Array(Int)->toParser(~variableName="propName"))->Expect.toBe(
      "propName->Array.map(Int.fromString)",
    )
    expect(Array(Float)->toParser(~variableName="propName"))->Expect.toBe(
      "propName->Array.map(Float.fromString)",
    )

    // Custom module, not required
    expect(
      Array(CustomModule({moduleName: "SomeModule", required: false}))->toParser(
        ~variableName="propName",
      ),
    )->Expect.toBe("propName->Array.map(value => value->SomeModule.parse)")

    // Custom module, not required
    expect(
      Array(CustomModule({moduleName: "SomeModule", required: true}))->toParser(
        ~variableName="propName",
      ),
    )->Expect.toBe("propName->Array.map(value => value->SomeModule.parse)")
  })
})

describe("Route slots", () => {
  test("generates typed slot components and outlet metadata", _t => {
    withGeneratedRoutes(
      `[
        {
          "name": "Shell",
          "path": "/?paneConfig=string",
          "slots": [{ "name": "Overlay" }],
          "children": [
            {
              "name": "Preferences",
              "path": "preferences",
              "outlet": "Overlay",
              "children": [
                {
                  "name": "Account",
                  "path": "account"
                }
              ]
            }
          ]
        }
      ]`,
      (~generatedPath) => {
        let routes = readGeneratedFile(~generatedPath, ~fileName="Routes.res")
        let shellRoute = readGeneratedFile(~generatedPath, ~fileName="Route__Shell_route.res")
        let routeDeclarations = readGeneratedFile(~generatedPath, ~fileName="RouteDeclarations.res")

        expect(routes)->Expect.String.toContain("module Slots = Route__Shell_route.Slots")
        expect(routes->String.includes("RelayRouter.Slot"))->Expect.toBe(false)
        expect(routes->String.includes("let "))->Expect.toBe(false)
        expect(shellRoute)->Expect.String.toContain("module Slots = {")
        expect(shellRoute)->Expect.String.toContain("module Overlay = {")
        expect(
          shellRoute,
        )->Expect.String.toContain(`<RelayRouter.Slot routeName="Shell" slotName="Overlay" ?fallback />`)
        expect(routeDeclarations)->Expect.String.toContain(`slots: ["Overlay"]`)
        expect(routeDeclarations)->Expect.String.toContain(`outlet: Some("Overlay")`)
        expect(routeDeclarations)->Expect.String.toContain(`effectiveOutlet: Some("Overlay")`)
        expect(routeDeclarations)->Expect.String.toContain(`module Shell = {`)
        expect(routeDeclarations)->Expect.String.toContain(`let routes = [makeShellRoute()]`)
        expect(
          routeDeclarations,
        )->Expect.String.toContain(`let compiledRoutes = routes->RelayRouter.Internal.compileRoutes`)
        expect(routeDeclarations)->Expect.String.toContain(`type outlet = Overlay`)
        expect(
          routeDeclarations,
        )->Expect.String.toContain(`let outletFromString: string => option<outlet> = outlet =>`)
        expect(routeDeclarations)->Expect.String.toContain(`| "Overlay" => Some(Overlay)`)
        expect(
          routeDeclarations,
        )->Expect.String.toContain(`RelayRouter.Internal.outletForUrl(compiledRoutes, url)->Option.flatMap(outletFromString)`)
        let accountRoute =
          routeDeclarations->sliceBetween(
            ~startMarker=`let routeName = "Shell__Preferences__Account"`,
            ~endMarker="children: [],",
          )
        expect(
          accountRoute,
        )->Expect.String.toContain(`let routeName = "Shell__Preferences__Account"`)
        expect(accountRoute)->Expect.String.toContain("outlet: None")
        expect(accountRoute)->Expect.String.toContain(`effectiveOutlet: Some("Overlay")`)
      },
    )
  })
})

describe("Route declarations", () => {
  test("generates standalone make modules only for top-level routes marked entrypoint", _t => {
    withGeneratedRoutes(
      `[
        {
          "name": "Root",
          "path": "/",
          "children": [
            {
              "name": "Dashboard",
              "path": "dashboard"
            }
          ]
        },
        {
          "name": "Admin",
          "path": "/admin",
          "entrypoint": true,
          "children": [
            {
              "name": "Users",
              "path": "users"
            }
          ]
        },
        {
          "name": "Embedded",
          "path": "/embedded",
          "entrypoint": false
        }
      ]`,
      (~generatedPath) => {
        let routeDeclarations = readGeneratedFile(~generatedPath, ~fileName="RouteDeclarations.res")
        let routeDeclarationsInterface = readGeneratedFile(
          ~generatedPath,
          ~fileName="RouteDeclarations.resi",
        )

        expect(routeDeclarations)->Expect.String.toContain("module Root = {")
        expect(routeDeclarations)->Expect.String.toContain("module Admin = {")
        expect(routeDeclarations)->Expect.String.toContain("module Embedded = {")
        let rootModule =
          routeDeclarations->sliceBetween(
            ~startMarker="module Root = {",
            ~endMarker="\n\nmodule Admin = {",
          )
        let embeddedModule =
          routeDeclarations->sliceBetween(
            ~startMarker="module Embedded = {",
            ~endMarker="\n\nlet make = (~prepareDisposeTimeout",
          )

        expect(rootModule)->Expect.String.toContain("let outletForUrl =")
        expect(rootModule)->Expect.not->Expect.String.toContain("let make =")
        expect(embeddedModule)->Expect.String.toContain("let outletForUrl =")
        expect(embeddedModule)->Expect.not->Expect.String.toContain("let make =")

        expect(routeDeclarations)->Expect.String.toContain(
          "let make = (~prepareDisposeTimeout=5 * 60 * 1000): array<RelayRouter.Types.route> =>",
        )
        let adminRouteMaker =
          routeDeclarations->sliceBetween(
            ~startMarker="let makeAdminRoute = ",
            ~endMarker="\n\nlet makeEmbeddedRoute = ",
          )
        expect(adminRouteMaker)->Expect.String.toContain(`let routeName = "Admin"`)
        expect(adminRouteMaker)->Expect.String.toContain(`let routeName = "Admin__Users"`)
        expect(adminRouteMaker)->Expect.not->Expect.String.toContain(`let routeName = "Root"`)
        expect(adminRouteMaker)->Expect.not->Expect.String.toContain(`let routeName = "Embedded"`)
        expect(
          routeDeclarations,
        )->Expect.String.toContain(`let make = (~prepareDisposeTimeout=5 * 60 * 1000): array<RelayRouter.Types.route> =>`)
        expect(routeDeclarationsInterface)->Expect.String.toContain("module Root: {")
        expect(routeDeclarationsInterface)->Expect.String.toContain("module Admin: {")
        expect(routeDeclarationsInterface)->Expect.String.toContain("module Embedded: {")
        expect(routeDeclarationsInterface)->Expect.String.toContain("type outlet")
        expect(routeDeclarationsInterface)->Expect.String.toContain(
          "let outletForUrl: string => option<outlet>",
        )
        expect(routeDeclarationsInterface)->Expect.String.toContain(
          "let make: (~prepareDisposeTimeout: int=?) => array<RelayRouter.Types.route>",
        )
      },
    )
  })

  test("preserves the existing all-routes RouteDeclarations.make output", _t => {
    withGeneratedRoutes(
      `[
        {
          "name": "Root",
          "path": "/"
        },
        {
          "name": "Admin",
          "path": "/admin",
          "entrypoint": true
        }
      ]`,
      (~generatedPath) => {
        let routeDeclarations = readGeneratedFile(~generatedPath, ~fileName="RouteDeclarations.res")

        expect(
          routeDeclarations,
        )->Expect.String.toContain(`let make = (~prepareDisposeTimeout=5 * 60 * 1000): array<RelayRouter.Types.route> =>`)
        expect(routeDeclarations)->Expect.String.toContain(`let routeName = "Root"`)
        expect(routeDeclarations)->Expect.String.toContain(`let routeName = "Admin"`)
      },
    )
  })
})

describe("Route key codegen", () => {
  test("emits path params through the collision-safe route key encoder", _t => {
    withSinglePrintableRoute(
      `[
      {
        "name": "Root",
        "path": "/:first/:second"
      }
    ]`,
      route => {
        let generated = RescriptRelayRouterCli__Codegen.getRouteDefinition(route, ~indentation=0)

        expect(generated)->Expect.String.toContain(`RelayRouter.Internal.RouteKey.make("Root")`)
        expect(
          generated,
        )->Expect.String.toContain(`RelayRouter.Internal.RouteKey.addPathParam(~name="first"`)
        expect(
          generated,
        )->Expect.String.toContain(`RelayRouter.Internal.RouteKey.addPathParam(~name="second"`)
      },
    )
  })

  test("emits scalar query params with explicit missing versus empty encoding", _t => {
    withSinglePrintableRoute(
      `[
      {
        "name": "Root",
        "path": "/?first=string&second=string"
      }
    ]`,
      route => {
        let generated = RescriptRelayRouterCli__Codegen.getRouteDefinition(route, ~indentation=0)

        expect(
          generated,
        )->Expect.String.toContain(`RelayRouter.Internal.RouteKey.addQueryParam(~name="first"`)
        expect(
          generated,
        )->Expect.String.toContain(`~value=queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("first")`)
        expect(
          generated,
        )->Expect.String.toContain(`RelayRouter.Internal.RouteKey.addQueryParam(~name="second"`)
        expect(
          generated,
        )->Expect.String.toContain(`~value=queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("second")`)
      },
    )
  })

  test("emits array query params using all repeated values", _t => {
    withSinglePrintableRoute(
      `[
      {
        "name": "Root",
        "path": "/?statuses=array<string>&after=string"
      }
    ]`,
      route => {
        let generated = RescriptRelayRouterCli__Codegen.getRouteDefinition(route, ~indentation=0)

        expect(
          generated,
        )->Expect.String.toContain(`RelayRouter.Internal.RouteKey.addQueryParamArray(~name="statuses"`)
        expect(
          generated,
        )->Expect.String.toContain(`~values=queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("statuses")`)
        expect(
          generated,
        )->Expect.String.toContain(`RelayRouter.Internal.RouteKey.addQueryParam(~name="after"`)
      },
    )
  })

  test("uses original URL param names when generated prop names need collision protection", _t => {
    withSinglePrintableRoute(
      `[
      {
        "name": "Root",
        "path": "/:environment?pathParams=string"
      }
    ]`,
      route => {
        let generated = RescriptRelayRouterCli__Codegen.getRouteDefinition(route, ~indentation=0)

        expect(
          generated,
        )->Expect.String.toContain(`RelayRouter.Internal.RouteKey.addPathParam(~name="environment", ~value=pathParams->Dict.get("environment")->Option.getOr(""))`)
        expect(
          generated,
        )->Expect.String.toContain(`RelayRouter.Internal.RouteKey.addQueryParam(~name="pathParams", ~value=queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("pathParams"))`)
      },
    )
  })
})

describe("Dump routes", () => {
  test("returns all routes in definition order by default", _t => {
    let {result} = TestUtils.parseMockContent(`[
      {
        "name": "Organization",
        "path": "/organization/:slug",
        "children": [
          {
            "name": "Members",
            "path": "members"
          }
        ]
      },
      {
        "name": "Root",
        "path": "/"
      },
      {
        "name": "Admin",
        "path": "/admin"
      }
    ]`)

    let dumped = DumpRoutes.dump(
      ~routes=result->U.routeChildrenToPrintable,
      ~config=testConfig,
      ~options={
        includeQueryParams: false,
        includeName: false,
        includeRouteRendererPath: false,
        includeRouteFilePath: false,
        sortOrder: DefinitionOrder,
      },
    )

    expect(
      dumped->stringifyDump,
    )->Expect.toBe(`[{"url":"/organization/:slug"},{"url":"/organization/:slug/members"},{"url":"/"},{"url":"/admin"}]`)
  })

  test("can sort routes alphabetically by URL", _t => {
    let {result} = TestUtils.parseMockContent(`[
      {
        "name": "Organization",
        "path": "/organization/:slug",
        "children": [
          {
            "name": "Members",
            "path": "members"
          }
        ]
      },
      {
        "name": "Root",
        "path": "/"
      },
      {
        "name": "Admin",
        "path": "/admin"
      }
    ]`)

    let dumped = DumpRoutes.dump(
      ~routes=result->U.routeChildrenToPrintable,
      ~config=testConfig,
      ~options={
        includeQueryParams: false,
        includeName: false,
        includeRouteRendererPath: false,
        includeRouteFilePath: false,
        sortOrder: Alphabetic,
      },
    )

    expect(
      dumped->stringifyDump,
    )->Expect.toBe(`[{"url":"/"},{"url":"/admin"},{"url":"/organization/:slug"},{"url":"/organization/:slug/members"}]`)
  })

  test("includes query params and requested metadata", _t => {
    let {result} = TestUtils.parseMockContent(`[
      {
        "name": "Organization",
        "path": "/organization/:slug?expandDetails=bool&displayMode=string",
        "children": [
          {
            "name": "Members",
            "path": "members?after=string&first=int"
          }
        ]
      }
    ]`)

    let dumped = DumpRoutes.dump(
      ~routes=result->U.routeChildrenToPrintable,
      ~config=testConfig,
      ~options={
        includeQueryParams: true,
        includeName: true,
        includeRouteRendererPath: true,
        includeRouteFilePath: true,
        sortOrder: Alphabetic,
      },
    )

    expect(
      dumped->stringifyDump,
    )->Expect.toBe(`[{"url":"/organization/:slug","queryParams":{"displayMode":":displayMode","expandDetails":":expandDetails"},"name":"Organization","routeRendererPath":"src/routes/Organization_route_renderer.res","routeFilePath":"src/routes/routes.json"},{"url":"/organization/:slug/members","queryParams":{"after":":after","displayMode":":displayMode","expandDetails":":expandDetails","first":":first"},"name":"Organization__Members","routeRendererPath":"src/routes/Organization__Members_route_renderer.res","routeFilePath":"src/routes/routes.json"}]`)
  })
})
