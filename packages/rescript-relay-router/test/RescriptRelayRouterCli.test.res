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
    expect(toTypeStr(CustomModule({moduleName: "SomeModule.SomeInnerModule"})))->Expect.toBe(
      "SomeModule.SomeInnerModule.t",
    )

    expect(toTypeStr(Array(String)))->Expect.toBe("array<string>")
    expect(toTypeStr(Array(Boolean)))->Expect.toBe("array<bool>")
    expect(toTypeStr(Array(Int)))->Expect.toBe("array<int>")
    expect(toTypeStr(Array(Float)))->Expect.toBe("array<float>")
    expect(toTypeStr(Array(CustomModule({moduleName: "SomeModule.SomeInnerModule"}))))->Expect.toBe(
      "array<SomeModule.SomeInnerModule.t>",
    )
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
      CustomModule({moduleName: "SomeModule"})->toSerializer(~variableName="propName"),
    )->Expect.toBe("propName->SomeModule.serialize->Js.Global.encodeURIComponent")

    /* Arrays */
    expect(Array(String)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Belt.Array.map(Js.Global.encodeURIComponent)->Js.Array2.joinWith(\",\")",
    )
    expect(Array(Boolean)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Belt.Array.map(string_of_bool)->Js.Array2.joinWith(\",\")",
    )
    expect(Array(Int)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Belt.Array.map(Belt.Int.toString)->Js.Array2.joinWith(\",\")",
    )
    expect(Array(Float)->toSerializer(~variableName="propName"))->Expect.toBe(
      "propName->Belt.Array.map(Js.Float.toString)->Js.Array2.joinWith(\",\")",
    )
    expect(
      Array(CustomModule({moduleName: "SomeModule"}))->toSerializer(~variableName="propName"),
    )->Expect.toBe(
      "propName->Belt.Array.map(value => value->SomeModule.serialize->Js.Global.encodeURIComponent)->Js.Array2.joinWith(\",\")",
    )
  })
})
