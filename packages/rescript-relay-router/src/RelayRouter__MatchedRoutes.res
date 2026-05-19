open RelayRouter__Types

let make = (matches: array<routeMatch>, preparedMatches: array<preparedMatch>): array<
  matchedRoute,
> =>
  matches->Array.mapWithIndex((match, index) => {
    let preparedMatch = preparedMatches->Array.get(index)
    {
      routeKey: preparedMatch->Option.map(match => match.routeKey)->Option.getOr(match.route.name),
      routeName: match.route.name,
      pathParams: match.params,
      slots: match.route.slots,
      outlet: match.route.outlet,
    }
  })
