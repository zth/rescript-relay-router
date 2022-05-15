module TargetScrollElement: {
  type context = {
    id: string,
    targetElementRef: React.ref<Js.Nullable.t<Dom.element>>,
  }

  type targetElementContext = option<context>

  module Provider: {
    @react.component
    let make: (
      ~id: string,
      ~targetElementRef: React.ref<Js.Nullable.t<Dom.element>>=?,
      ~children: React.element,
    ) => React.element
  }

  let useTargetElement: unit => targetElementContext
}

module ScrollRestoration: {
  @react.component
  let make: unit => React.element
}
