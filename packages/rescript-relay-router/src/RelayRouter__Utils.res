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
    getLocation,
    markNextNavigationAsShallow,
  } = RelayRouter__Context.useRouterContext()
  let push = React.useCallback((path, ~shallow=false) => {
    switch shallow {
    | true => markNextNavigationAsShallow()
    | false => ()
    }
    postRouterEvent(OnBeforeNavigation({currentLocation: getLocation()}))
    history->RelayRouter__History.push(path)
  }, (history, postRouterEvent, getLocation, markNextNavigationAsShallow))
  let replace = React.useCallback((path, ~shallow=false) => {
    switch shallow {
    | true => markNextNavigationAsShallow()
    | false => ()
    }
    postRouterEvent(OnBeforeNavigation({currentLocation: getLocation()}))
    history->RelayRouter__History.replace(path)
  }, (history, postRouterEvent, getLocation, markNextNavigationAsShallow))

  {
    push,
    replace,
    preload,
    preloadCode,
  }
}

let useLocation = () => {
  let router = RelayRouter__Context.useRouterContext()

  React.useSyncExternalStoreWithServerSnapshot(~subscribe=callback =>
    router.subscribeToLocation(_location => {
      callback()
    })
  , ~getSnapshot=router.getLocation, ~getServerSnapshot=router.getLocation)
}

let isRouteActive = (~pathname, ~routePattern, ~exact=false) => {
  RelayRouter__Internal.matchPathWithOptions(
    {"path": routePattern, "end": exact},
    pathname,
  )->Option.isSome
}

let useIsRouteActive = (~routePattern, ~exact=false) => {
  let {pathname} = useLocation()

  React.useMemo(
    () => isRouteActive(~pathname, ~routePattern, ~exact),
    (pathname, routePattern, exact),
  )
}
