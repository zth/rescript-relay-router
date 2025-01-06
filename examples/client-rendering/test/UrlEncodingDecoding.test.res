open RescriptRelayRouterUtils.Vitest

describe("makeLink", () => {
  test("should generate link with statuses", _t => {
    let link = Routes.Root.Todos.Route.makeLink(
      ~statuses=[TodoStatus.Completed, TodoStatus.NotCompleted],
    )
    expect(link)->Expect.toBe("/todos?statuses=completed,not-completed")
  })

  test("should generate link without statuses", _t => {
    let link = Routes.Root.Todos.Route.makeLink()
    expect(link)->Expect.toBe("/todos")
  })

  test("should generate link correctly URI encoded", _t => {
    let link = Routes.Root.Todos.Route.makeLink(~byValue="/incorrect value, for url")
    expect(link)->Expect.toBe("/todos?byValue=%2Fincorrect%20value%2C%20for%20url")
  })

  test("should omit query param when value is default value", _t => {
    let link = Routes.Root.Todos.Route.makeLink(~statusWithDefault=NotCompleted)
    expect(link)->Expect.toBe("/todos")
  })
})

describe("parsing", () => {
  test("query params are correctly decoded", _t => {
    let queryParams = Routes.Root.Todos.Route.parseQueryParams(
      "?byValue=%2Fincorrect%20value%2C%20for%20url",
    )
    expect(queryParams.byValue->Option.getExn)->Expect.toBe("/incorrect value, for url")
  })
})
