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
      "propName->Js.Global.encodeURIComponent",
    )
    expect(Boolean->toSerializer(~variableName="propName"))->Expect.toBe("string_of_bool(propName)")
    expect(Int->toSerializer(~variableName="propName"))->Expect.toBe("Belt.Int.toString(propName)")
    expect(Float->toSerializer(~variableName="propName"))->Expect.toBe(
      "Js.Float.toString(propName)",
    )
    expect(
      CustomModule({moduleName: "SomeModule", required: false})->toSerializer(
        ~variableName="propName",
      ),
    )->Expect.toBe("propName->SomeModule.serialize->Js.Global.encodeURIComponent")

    /* Arrays */
    expect(Array(String)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Belt.Array.map(Js.Global.encodeURIComponent)",
    )
    expect(Array(Boolean)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Belt.Array.map(string_of_bool)",
    )
    expect(Array(Int)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Belt.Array.map(Belt.Int.toString)",
    )
    expect(Array(Float)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Belt.Array.map(Js.Float.toString)",
    )
    expect(
      Array(CustomModule({moduleName: "SomeModule", required: false}))->toSerializer(
        ~variableName="propName",
      ),
    )->Expect.toBe(
      "propName->Belt.Array.map(value => value->SomeModule.serialize->Js.Global.encodeURIComponent)",
    )
  })

  test("emits parse code for query params", _t => {
    open U.QueryParams

    expect(String->toParser(~variableName="propName"))->Expect.toBe(
      "Some(propName->Js.Global.decodeURIComponent)",
    )
    expect(Int->toParser(~variableName="propName"))->Expect.toBe("Belt.Int.fromString(propName)")
    expect(Float->toParser(~variableName="propName"))->Expect.toBe("Js.Float.fromString(propName)")

    expect(
      CustomModule({moduleName: "SomeModule", required: false})->toParser(~variableName="propName"),
    )->Expect.toBe("propName->Js.Global.decodeURIComponent->SomeModule.parse")

    expect(
      CustomModule({moduleName: "SomeModule", required: true})->toParser(~variableName="propName"),
    )->Expect.toBe(
      "propName->Js.Global.decodeURIComponent->SomeModule.parse->Belt.Option.getWithDefault(SomeModule.defaultValue)",
    )

    /* Arrays */
    expect(Array(String)->toParser(~variableName="propName"))->Expect.toBe(
      "propName->Js.Global.decodeURIComponent",
    )
    expect(Array(Int)->toParser(~variableName="propName"))->Expect.toBe(
      "propName->Belt.Array.map(Belt.Int.fromString)",
    )
    expect(Array(Float)->toParser(~variableName="propName"))->Expect.toBe(
      "propName->Belt.Array.map(Js.Float.fromString)",
    )

    // Custom module, not required
    expect(
      Array(CustomModule({moduleName: "SomeModule", required: false}))->toParser(
        ~variableName="propName",
      ),
    )->Expect.toBe(
      "propName->Belt.Array.map(value => value->Js.Global.decodeURIComponent->SomeModule.parse)",
    )

    // Custom module, not required
    expect(
      Array(CustomModule({moduleName: "SomeModule", required: true}))->toParser(
        ~variableName="propName",
      ),
    )->Expect.toBe(
      "propName->Belt.Array.map(value => value->Js.Global.decodeURIComponent->SomeModule.parse->Belt.Option.getWithDefault(SomeModule.defaultValue))",
    )
  })
})
