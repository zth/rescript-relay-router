// Credits: A lot of this implementation is taken from (or at least inspired by) Next.js/Remix/React Router.

type listenerCallback = unit => unit

@val
external addBeforeUnloadListener: (@as(json`"beforeunload"`) _, listenerCallback) => unit =
  "window.addEventListener"

@val
external removeBeforeUnloadListener: (@as(json`"beforeunload"`) _, listenerCallback) => unit =
  "window.removeEventListener"

@val @return(nullable)
external getScrollPositions: (
  @as(json`"RESCRIPT_RELAY_ROUTER_SCROLL_POS"`) _,
  unit,
) => option<string> = "sessionStorage.getItem"

@val
external setScrollPositions: (@as(json`"RESCRIPT_RELAY_ROUTER_SCROLL_POS"`) _, string) => unit =
  "sessionStorage.setItem"

external castToPositionsShape: JSON.t => dict<int> = "%identity"

let scrollPositionsY = ref(
  if RelaySSRUtils.ssr {
    dict{}
  } else {
    try {
      getScrollPositions()
      ->Option.map(positionsRaw => positionsRaw->JSON.parseExn->castToPositionsShape)
      ->Option.getOr(dict{})
    } catch {
    | JsExn(_) => dict{}
    }
  },
)

module TargetScrollElement = {
  type context = {
    id: string,
    targetElementRef: React.ref<Nullable.t<Dom.element>>,
  }

  type targetElementContext = option<context>

  let context: React.Context.t<targetElementContext> = React.createContext(None)

  module ContextProvider = {
    let make = React.Context.provider(context)
  }

  module Provider = {
    @react.component
    let make = (~id, ~targetElementRef=?, ~children) => {
      <ContextProvider value={React.useMemo(() =>
          switch targetElementRef {
          | None => None
          | Some(targetElementRef) =>
            Some(
              (
                {
                  id,
                  targetElementRef,
                }: context
              ),
            )
          }
        , (id, targetElementRef))}> {children} </ContextProvider>
    }
  }

  let useTargetElement = () => React.useContext(context)
}

let getScrollPosId = (location, ~id) => id ++ ":" ++ location.RelayRouter__History.key

module ScrollRestoration = {
  @val
  external window: Dom.element = "window"

  @send
  external scrollToYOnElement: (Dom.element, @as(json`0`) _, ~y: int) => unit = "scrollTo"

  @send
  external scrollElementIntoView: Dom.element => unit = "scrollIntoView"

  @get
  external scrollTop: Dom.element => int = "scrollTop"

  @val @return(nullable)
  external getElementById: string => option<Dom.element> = "document.getElementById"

  type targetElement = Window(Dom.element) | Element(React.ref<Nullable.t<Dom.element>>)

  let getElement = targetElement =>
    switch targetElement {
    | Window(window) => Some(window)
    | Element(ref) => ref.current->Nullable.toOption
    }

  @react.component
  let make = () => {
    let location = RelayRouter__Utils.useLocation()
    let router = RelayRouter__Context.useRouterContext()
    let targetEl = TargetScrollElement.useTargetElement()
    let (id, targetElement) = React.useMemo(() =>
      switch targetEl {
      | None => ("window", Window(window))
      | Some({targetElementRef, id}) => (id, Element(targetElementRef))
      }
    , [targetEl])

    let setScrollPosition = React.useCallback(() => {
      switch targetElement->getElement {
      | None => ()
      | Some(targetElement) =>
        scrollPositionsY.contents->Dict.set(location->getScrollPosId(~id), targetElement->scrollTop)
      }
    }, (location, targetElement, id))

    let persistScrollPositions = React.useCallback(priority => {
      switch targetElement->getElement {
      | None => ()
      | Some(targetElement) =>
        scrollPositionsY.contents->Dict.set(location->getScrollPosId(~id), targetElement->scrollTop)
        let _ = RelayRouter__Internal.runAtPriority(~priority, () => {
          switch scrollPositionsY.contents->JSON.stringifyAny {
          | None => ()
          | Some(stringifiedPositions) => setScrollPositions(stringifiedPositions)
          }
        })
      }
    }, (location, targetElement, id))

    let onBeforeUnload = React.useCallback(() => {
      setScrollPosition()
      persistScrollPositions(High)
    }, (setScrollPosition, persistScrollPositions))

    React.useEffect(() => {
      addBeforeUnloadListener(onBeforeUnload)

      Some(
        () => {
          removeBeforeUnloadListener(onBeforeUnload)
        },
      )
    }, [onBeforeUnload])

    // Ensure new positions are persisted
    React.useEffect(() => {
      let unsub = router.subscribeToEvent(event => {
        switch event {
        | OnBeforeNavigation(_) =>
          setScrollPosition()
          persistScrollPositions(Low)
        | RestoreScroll(location) =>
          switch (
            targetElement->getElement,
            scrollPositionsY.contents->Dict.get(location->getScrollPosId(~id)),
          ) {
          | (None, _) => ()
          | (Some(targetElement), Some(y)) => targetElement->scrollToYOnElement(~y)
          | (Some(targetElement), None) =>
            // If there's a hash, we'll try to scroll to it. If not, we'll scroll to top
            switch location.hash->String.sliceToEnd(~start=1)->getElementById {
            | None =>
              // No hash, scroll to top
              targetElement->scrollToYOnElement(~y=0)
            | Some(hashElement) => hashElement->scrollElementIntoView
            }
          }
        | OnRouteWillUnmount(_) => ()
        }
      })

      Some(unsub)
    }, (
      router.subscribeToEvent,
      setScrollPosition,
      persistScrollPositions,
      targetElement,
      location,
    ))

    React.null
  }
}
