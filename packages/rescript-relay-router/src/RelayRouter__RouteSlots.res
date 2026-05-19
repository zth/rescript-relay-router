open RelayRouter__Types

let slotKey = (~routeName, ~slotName) => `${routeName}::${slotName}`

module RouteComponent = {
  @react.component
  let make = (~render: renderRouteFn, ~children) => {
    render(~childRoutes=children)
  }
}

let renderPreparedMatches = (matches: array<preparedMatch>): React.element => {
  matches
  ->Array.toReversed
  ->Array.reduce(React.null, (renderedContent, {render}) =>
    <RouteComponent render> {renderedContent} </RouteComponent>
  )
}

type outletMatch = {index: int, slotName: string}
type slotBranch = {
  hostRouteName: string,
  slotName: string,
  matches: array<preparedMatch>,
}
type splitAccumulator = {
  primaryMatches: List.t<preparedMatch>,
  slotMatches: List.t<preparedMatch>,
  index: int,
}

let rec findFirstOutlet = (matches: List.t<preparedMatch>, index: int): option<outletMatch> =>
  switch matches {
  | list{} => None
  | list{match, ...rest} =>
    switch match.outlet {
    | Some(slotName) => Some({index, slotName})
    | None => findFirstOutlet(rest, index + 1)
    }
  }

let rec findSlotHostIndex = (
  matches: List.t<preparedMatch>,
  ~outletIndex: int,
  ~slotName: string,
  ~index: int,
  ~lastHost: option<int>,
): option<int> =>
  switch matches {
  | list{} => lastHost
  | list{match, ...rest} =>
    switch index >= outletIndex {
    | true => lastHost
    | false =>
      let nextHost = switch match.slots->Array.includes(slotName) {
      | true => Some(index)
      | false => lastHost
      }
      findSlotHostIndex(rest, ~outletIndex, ~slotName, ~index=index + 1, ~lastHost=nextHost)
    }
  }

let splitMatchesAtHost = (preparedMatches: array<preparedMatch>, ~hostIndex: int): (
  array<preparedMatch>,
  array<preparedMatch>,
) => {
  let {primaryMatches, slotMatches} = preparedMatches->Array.reduce(
    ({primaryMatches: list{}, slotMatches: list{}, index: 0}: splitAccumulator),
    (acc, match) =>
      switch acc.index <= hostIndex {
      | true => {
          ...acc,
          primaryMatches: list{match, ...acc.primaryMatches},
          index: acc.index + 1,
        }
      | false => {
          ...acc,
          slotMatches: list{match, ...acc.slotMatches},
          index: acc.index + 1,
        }
      },
  )

  (primaryMatches->List.reverse->List.toArray, slotMatches->List.reverse->List.toArray)
}

let splitPreparedMatches = (preparedMatches: array<preparedMatch>): (
  array<preparedMatch>,
  option<slotBranch>,
) => {
  let allMatchesList = preparedMatches->List.fromArray

  switch allMatchesList->findFirstOutlet(0) {
  | Some({index: outletIndex, slotName}) =>
    switch allMatchesList->findSlotHostIndex(~outletIndex, ~slotName, ~index=0, ~lastHost=None) {
    | Some(hostIndex) =>
      let (primaryMatches, slotMatches) = preparedMatches->splitMatchesAtHost(~hostIndex)
      switch primaryMatches->Array.get(hostIndex) {
      | Some(hostMatch) => (
          primaryMatches,
          Some({
            hostRouteName: hostMatch.routeName,
            slotName,
            matches: slotMatches,
          }),
        )
      | None => (preparedMatches, None)
      }
    | None => (preparedMatches, None)
    }
  | None => (preparedMatches, None)
  }
}

let routeSetFromPreparedMatches = (
  preparedMatches: array<preparedMatch>,
  ~location,
  ~queryParams,
  ~matchedRoutes,
): currentRouterEntry => {
  let (primaryMatches, slotBranch) = preparedMatches->splitPreparedMatches

  let slotContents = switch slotBranch {
  | Some({hostRouteName, slotName, matches}) =>
    let slotContents = dict{}
    slotContents->Dict.set(
      slotKey(~routeName=hostRouteName, ~slotName),
      matches->renderPreparedMatches,
    )
    slotContents
  | None => dict{}
  }

  {
    location,
    queryParams,
    matchedRoutes,
    preparedMatches,
    primaryMatches,
    slotContents,
    allMatches: preparedMatches,
  }
}
