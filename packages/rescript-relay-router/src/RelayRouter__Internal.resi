let setQueryParams: (
  RelayRouter__Bindings.QueryParams.t,
  RelayRouter__Types.setQueryParamsMode,
  RelayRouter__Bindings.History.t,
) => unit

type pathMatch

@module("react-router") @return(nullable)
external matchPath: (string, string) => option<pathMatch> = "matchPath"

@module("react-router") @return(nullable)
external matchPathWithOptions: ({"path": string, "end": bool}, string) => option<pathMatch> =
  "matchPath"

let extractDisposables: (. 'any) => array<(. unit) => unit>

let runAtPriority: (
  RelayRouter__Types.callback,
  ~priority: RelayRouter__Types.preloadPriority,
) => option<unit => unit>
