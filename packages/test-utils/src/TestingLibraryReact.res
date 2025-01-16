type renderHookResult<'res> = private {current: 'res}

type renderHookResultWrapper<'res> = private {
  result: renderHookResult<'res>,
  rerender: unit => unit,
}

module Wrapper = {
  type props = {children: Jsx.element}
  type t = props => Jsx.element
}

type renderHooksOptions = {wrapper: Wrapper.t}

@module("@testing-library/react")
external renderHook: (unit => 'a, ~options: renderHooksOptions=?) => renderHookResultWrapper<'a> =
  "renderHook"

@module("@testing-library/react")
external act: (unit => unit) => unit = "act"
