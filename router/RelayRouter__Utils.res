open RelayRouter__Bindings

let childRouteHasContent = childRoute => childRoute != React.null

@live
type routerHelpers = {
  push: string => unit,
  replace: string => unit,
  preload: (string, ~priority: RelayRouter__Types.preloadPriority=?, unit) => unit,
  preloadCode: (string, ~priority: RelayRouter__Types.preloadPriority=?, unit) => unit,
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
    history->History.push(path)
  }, (history, postRouterEvent))
  let replace = React.useCallback2(path => {
    postRouterEvent(OnBeforeNavigation({currentLocation: get().location}))
    history->History.replace(path)
  }, (history, postRouterEvent))

  {
    push: push,
    replace: replace,
    preload: preload,
    preloadCode: preloadCode,
  }
}

let useLocation = () => {
  let router = RelayRouter__Context.useRouterContext()
  let (location, setLocation) = React.useState(() => router.history->History.getLocation)

  React.useEffect1(() => {
    let unsub = router.history->History.listen(({location}) => {
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

module AssetPreloader = {
  @val
  external appendToHead: Dom.element => unit = "document.head.appendChild"

  @val @scope("document")
  external createLinkElement: (@as("link") _, unit) => Dom.element = "createElement"

  @val @scope("document")
  external createScriptElement: (@as("script") _, unit) => Dom.element = "createElement"

  @set
  external setHref: (Dom.element, string) => unit = "href"

  @set
  external setRel: (Dom.element, [#modulepreload | #preload]) => unit = "rel"

  @set
  external setAs: (Dom.element, [#image]) => unit = "as"

  @set
  external setAsync: (Dom.element, bool) => unit = "async"

  @set
  external setSrc: (Dom.element, string) => unit = "src"

  @set
  external setScriptType: (Dom.element, [#"module"]) => unit = "type"

  @live
  let preloadAssetViaLinkTag = asset => {
    let element = createLinkElement()

    switch asset {
    | RelayRouter__Types.Component({chunk}) =>
      element->setHref(chunk)
      element->setRel(#modulepreload)
    | Image({url}) =>
      element->setHref(url)
      element->setRel(#preload)
      element->setAs(#image)
    }

    appendToHead(element)
  }

  @live
  let loadScriptTag = (~isModule=false, src) => {
    let element = createScriptElement()

    element->setSrc(src)
    element->setAsync(true)

    if isModule {
      element->setScriptType(#"module")
    }

    appendToHead(element)
  }

  let preloadAsset = (asset, ~priority, ~preparedAssetsMap) => {
    let assetIdentifier = switch asset {
    | RelayRouter__Types.Component({chunk}) => "component:" ++ chunk
    | Image({url}) => "image:" ++ url
    }

    switch preparedAssetsMap->Js.Dict.get(assetIdentifier) {
    | Some(_) => // Already preloaded
      ()
    | None =>
      preparedAssetsMap->Js.Dict.set(assetIdentifier, true)
      switch (asset, priority) {
      | (Component(_), RelayRouter__Types.Default | Low) => preloadAssetViaLinkTag(asset)
      | (Component({chunk}), High) => chunk->loadScriptTag(~isModule=true)
      | _ => // Unimplemented
        ()
      }
    }
  }
}
