@module("react-helmet") @react.component
external make: (
  ~children: React.element,
  ~titleTemplate: option<string>=?,
  ~defaultTitle: option<string>=?,
) => React.element = "Helmet"
