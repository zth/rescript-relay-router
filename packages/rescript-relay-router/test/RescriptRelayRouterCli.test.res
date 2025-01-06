open Vitest
open RescriptRelayRouterCli__Types

module U = RescriptRelayRouterCli__Utils

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

    expect(String->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->encodeURIComponent",
    )
    expect(
      Boolean->toSerializer(~variableName="propName"),
    )->Expect.toBe(`switch propName { | true => "true" | false => "false" }`)
    expect(Int->toSerializer(~variableName="propName"))->Expect.toBe("Int.toString(propName)")
    expect(Float->toSerializer(~variableName="propName"))->Expect.toBe("Float.toString(propName)")
    expect(
      CustomModule({moduleName: "SomeModule", required: false})->toSerializer(
        ~variableName="propName",
      ),
    )->Expect.toBe("propName->SomeModule.serialize->encodeURIComponent")

    /* Arrays */
    expect(Array(String)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Array.map(encodeURIComponent)",
    )
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
    )->Expect.toBe("propName->Array.map(value => value->SomeModule.serialize->encodeURIComponent)")
  })

  test("emits parse code for query params", _t => {
    open U.QueryParams

    expect(String->toParser(~variableName="propName"))->Expect.toBe(
      "Some(propName->decodeURIComponent)",
    )
    expect(Int->toParser(~variableName="propName"))->Expect.toBe("Int.fromString(propName)")
    expect(Float->toParser(~variableName="propName"))->Expect.toBe("Float.fromString(propName)")

    expect(
      CustomModule({moduleName: "SomeModule", required: false})->toParser(~variableName="propName"),
    )->Expect.toBe("propName->decodeURIComponent->SomeModule.parse")

    expect(
      CustomModule({moduleName: "SomeModule", required: true})->toParser(~variableName="propName"),
    )->Expect.toBe("propName->decodeURIComponent->SomeModule.parse")

    /* Arrays */
    expect(Array(String)->toParser(~variableName="propName"))->Expect.toBe(
      "propName->decodeURIComponent",
    )
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
    )->Expect.toBe("propName->Array.map(value => value->decodeURIComponent->SomeModule.parse)")

    // Custom module, not required
    expect(
      Array(CustomModule({moduleName: "SomeModule", required: true}))->toParser(
        ~variableName="propName",
      ),
    )->Expect.toBe("propName->Array.map(value => value->decodeURIComponent->SomeModule.parse)")
  })
})
