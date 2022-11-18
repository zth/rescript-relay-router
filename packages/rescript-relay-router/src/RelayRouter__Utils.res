let childRouteHasContent = childRoute => childRoute != React.null

@live
type routerHelpers = {
  push: string => unit,
  replace: string => unit,
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
  } = RelayRouter__Context.useRouterContext()
  let push = React.useCallback2(path => {
    postRouterEvent(OnBeforeNavigation({currentLocation: get().location}))
    history->RelayRouter__History.push(path)
  }, (history, postRouterEvent))
  let replace = React.useCallback2(path => {
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

  React.useEffect1(() => {
    let unsub = router.history->RelayRouter__History.listen(({location}) => {
      setLocation(_ => location)
    })

    Some(unsub)
  }, [router.history])

  location
}

let isRouteActive = (~pathname, ~routePattern, ~exact=false, ()) => {
  RelayRouter__Internal.matchPathWithOptions(
    {"path": routePattern, "end": exact},
    pathname,
  )->Belt.Option.isSome
}

let useIsRouteActive = (~href, ~routePattern, ~exact=false, ()) => {
  let {pathname} = useLocation()

  React.useMemo4(
    () => isRouteActive(~pathname, ~routePattern, ~exact, ()),
    (pathname, href, routePattern, exact),
  )
}
