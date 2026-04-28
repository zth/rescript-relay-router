open RescriptRelayRouterTestUtils.Vitest
open RescriptRelayRouterCli__Types

module U = RescriptRelayRouterCli__Utils
module DumpRoutes = RescriptRelayRouterCli__DumpRoutes

let stringifyDump = dumped => dumped->Array.map(route => JSON.Object(route))->JSON.Array->JSON.stringify

let testConfig = {
  generatedPath: "src/routes/__generated__",
  routesFolderPath: "src/routes",
  rescriptLibFolderPath: "lib/bs",
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

    let dumped =
      DumpRoutes.dump(
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

    expect(dumped->stringifyDump)->Expect.toBe(
      `[{"url":"/organization/:slug"},{"url":"/organization/:slug/members"},{"url":"/"},{"url":"/admin"}]`,
    )
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

    let dumped =
      DumpRoutes.dump(
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

    expect(dumped->stringifyDump)->Expect.toBe(
      `[{"url":"/"},{"url":"/admin"},{"url":"/organization/:slug"},{"url":"/organization/:slug/members"}]`,
    )
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

    let dumped =
      DumpRoutes.dump(
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

    expect(dumped->stringifyDump)->Expect.toBe(
      `[{"url":"/organization/:slug","queryParams":{"displayMode":":displayMode","expandDetails":":expandDetails"},"name":"Organization","routeRendererPath":"src/routes/Organization_route_renderer.res","routeFilePath":"src/routes/routes.json"},{"url":"/organization/:slug/members","queryParams":{"after":":after","displayMode":":displayMode","expandDetails":":expandDetails","first":":first"},"name":"Organization__Members","routeRendererPath":"src/routes/Organization__Members_route_renderer.res","routeFilePath":"src/routes/routes.json"}]`,
    )
  })
})
