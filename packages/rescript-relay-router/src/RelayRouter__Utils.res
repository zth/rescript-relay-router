let childRouteHasContent = childRoute => childRoute != React.null

@live
type routerHelpers = {
  push: (string, ~shallow: bool=?) => unit,
  replace: (string, ~shallow: bool=?) => unit,
  preload: RelayRouter__Types.preloadFn,
  preloadCode: RelayRouter__Types.preloadCodeFn,
}

@live
let useRouter = (): routerHelpers => {
  let {
    history,
    preload,
    preloadCode,
    postRouterEvent,
    get,
    markNextNavigationAsShallow,
  } = RelayRouter__Context.useRouterContext()
  let push = React.useCallback((path, ~shallow=false) => {
    if shallow {
      markNextNavigationAsShallow()
    }
    postRouterEvent(OnBeforeNavigation({currentLocation: get().location}))
    history->RelayRouter__History.push(path)
  }, (history, postRouterEvent))
  let replace = React.useCallback((path, ~shallow=false) => {
    if shallow {
      markNextNavigationAsShallow()
    }
    postRouterEvent(OnBeforeNavigation({currentLocation: get().location}))
    history->RelayRouter__History.replace(path)
  }, (history, postRouterEvent))

  {
    push,
    replace,
    preload,
    preloadCode,
  }
}

let useLocation = () => {
  let router = RelayRouter__Context.useRouterContext()
  let (location, setLocation) = React.useState(() =>
    router.history->RelayRouter__History.getLocation
  )

  React.useEffect(() => {
    let unsub = router.history->RelayRouter__History.listen(({location}) => {
      setLocation(_ => location)
    })

    Some(unsub)
  }, [router.history])

  location
}

let isRouteActive = (~pathname, ~routePattern, ~exact=false) => {
  RelayRouter__Internal.matchPathWithOptions(
    {"path": routePattern, "end": exact},
    pathname,
  )->Belt.Option.isSome
}

let useIsRouteActive = (~routePattern, ~exact=false) => {
  let {pathname} = useLocation()

  React.useMemo(
    () => isRouteActive(~pathname, ~routePattern, ~exact),
    (pathname, routePattern, exact),
  )
}
