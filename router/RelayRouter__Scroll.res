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

external castToPositionsShape: Js.Json.t => Js.Dict.t<int> = "%identity"

let scrollPositionsY = ref(
  if RelaySSRUtils.ssr {
    Js.Dict.empty()
  } else {
    try {
      getScrollPositions()
      ->Belt.Option.map(positionsRaw => positionsRaw->Js.Json.parseExn->castToPositionsShape)
      ->Belt.Option.getWithDefault(Js.Dict.empty())
    } catch {
    | Js.Exn.Error(_) => Js.Dict.empty()
    }
  },
)

module TargetScrollElement = {
  type context = {
    id: string,
    targetElementRef: React.ref<Js.Nullable.t<Dom.element>>,
  }

  type targetElementContext = option<context>

  let context: React.Context.t<targetElementContext> = React.createContext(None)

  module ContextProvider = {
    let make = React.Context.provider(context)

    let makeProps = (~value, ~children, ()) =>
      {
        "value": value,
        "children": children,
      }
  }

  module Provider = {
    @react.component
    let make = (~id, ~targetElementRef=?, ~children) => {
      <ContextProvider value={React.useMemo2(() =>
          switch targetElementRef {
          | None => None
          | Some(targetElementRef) =>
            Some({
              id: id,
              targetElementRef: targetElementRef,
            })
          }
        , (id, targetElementRef))}> {children} </ContextProvider>
    }
  }

  let useTargetElement = () => React.useContext(context)
}

let getScrollPosId = (location, ~id) => id ++ ":" ++ location.RelayRouter__Bindings.History.key

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

  type targetElement = Window(Dom.element) | Element(React.ref<Js.Nullable.t<Dom.element>>)

  let getElement = targetElement =>
    switch targetElement {
    | Window(window) => Some(window)
    | Element(ref) => ref.current->Js.Nullable.toOption
    }

  @react.component
  let make = () => {
    let location = RelayRouter__Utils.useLocation()
    let router = RelayRouter__Context.useRouterContext()
    let targetEl = TargetScrollElement.useTargetElement()
    let (id, targetElement) = React.useMemo1(() =>
      switch targetEl {
      | None => ("window", Window(window))
      | Some({targetElementRef, id}) => (id, Element(targetElementRef))
      }
    , [targetEl])

    let setScrollPosition = React.useCallback3(() => {
      switch targetElement->getElement {
      | None => ()
      | Some(targetElement) =>
        scrollPositionsY.contents->Js.Dict.set(
          location->getScrollPosId(~id),
          targetElement->scrollTop,
        )
      }
    }, (location, targetElement, id))

    let persistScrollPositions = React.useCallback3(priority => {
      switch targetElement->getElement {
      | None => ()
      | Some(targetElement) =>
        scrollPositionsY.contents->Js.Dict.set(
          location->getScrollPosId(~id),
          targetElement->scrollTop,
        )
        let _ = RelayRouter__Internal.runAtPriority(~priority, () => {
          switch scrollPositionsY.contents->Js.Json.stringifyAny {
          | None => ()
          | Some(stringifiedPositions) => setScrollPositions(stringifiedPositions)
          }
        })
      }
    }, (location, targetElement, id))

    let onBeforeUnload = React.useCallback2(() => {
      setScrollPosition()
      persistScrollPositions(High)
    }, (setScrollPosition, persistScrollPositions))

    React.useEffect1(() => {
      addBeforeUnloadListener(onBeforeUnload)

      Some(
        () => {
          removeBeforeUnloadListener(onBeforeUnload)
        },
      )
    }, [onBeforeUnload])

    // Ensure new positions are persisted
    React.useEffect5(() => {
      let unsub = router.subscribeToEvent(event => {
        switch event {
        | OnBeforeNavigation(_) =>
          setScrollPosition()
          persistScrollPositions(Low)
        | RestoreScroll(location) =>
          switch (
            targetElement->getElement,
            scrollPositionsY.contents->Js.Dict.get(location->getScrollPosId(~id)),
          ) {
          | (None, _) => ()
          | (Some(targetElement), Some(y)) => targetElement->scrollToYOnElement(~y)
          | (Some(targetElement), None) =>
            // If there's a hash, we'll try to scroll to it. If not, we'll scroll to top
            switch location.hash->Js.String2.sliceToEnd(~from=1)->getElementById {
            | None =>
              // No hash, scroll to top
              targetElement->scrollToYOnElement(~y=0)
            | Some(hashElement) => hashElement->scrollElementIntoView
            }
          }
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
