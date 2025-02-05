open RelayRouter__Types
open RelayRouter__Scroll

let isModifiedEvent = e => {
  open ReactEvent.Mouse
  switch (e->metaKey, e->altKey, e->ctrlKey, e->shiftKey) {
  | (true, _, _, _)
  | (_, true, _, _) => true
  | (_, _, true, _) => true
  | (_, _, _, true) => true
  | _ => false
  }
}

module IntersectionObserver = {
  type t
  type observerEntry = {
    isIntersecting: bool,
    target: Dom.element,
  }
  type callback = array<observerEntry> => unit

  @send
  external observe: (t, Dom.element) => unit = "observe"

  @send
  external disconnect: t => unit = "disconnect"

  @new
  external make: (callback, {"threshold": float, "root": option<Dom.element>}) => t =
    "IntersectionObserver"
}

@live
type preloadMode = NoPreloading | OnRender | OnIntent | OnInView

@react.component
let make = (
  ~to_,
  ~title=?,
  ~id=?,
  ~className=?,
  ~target as browserTarget=?,
  ~mode=#push,
  ~preloadPriority=Default,
  ~preloadData=OnIntent,
  ~preloadCode=OnInView,
  ~children,
  ~onClick=?,
  ~style=?,
  ~tabIndex=?,
) => {
  let linkElement = React.useRef(null)
  let hasPreloaded = React.useRef(false)
  let router = RelayRouter__Context.useRouterContext()
  let {history} = router
  let targetElementRef = TargetScrollElement.useTargetElement()
  let startTransition = RelayRouter__Internal.RouterTransitionContext.use()

  let changeRoute = React.useCallback(e =>
    startTransition(() => {
      router.postRouterEvent(OnBeforeNavigation({currentLocation: router.get().location}))
      open ReactEvent.Mouse
      switch (e->isDefaultPrevented, e->button, browserTarget, e->isModifiedEvent) {
      | (false, 0, None | Some(#self), false) =>
        e->preventDefault
        switch mode {
        | #push => history->RelayRouter__History.push(to_)
        | #replace => history->RelayRouter__History.replace(to_)
        }
      | _ => ()
      }
    })
  , (to_, history, router.postRouterEvent, startTransition))

  let doPreloadDataAndCode = React.useCallback(
    overridePriority =>
      to_->router.preload(~priority=overridePriority->Option.getOr(preloadPriority)),
    (to_, router.preload, preloadPriority),
  )
  let doPreloadCode = React.useCallback(
    overridePriority =>
      to_->router.preloadCode(~priority=overridePriority->Option.getOr(preloadPriority)),
    (to_, router.preloadCode, preloadPriority),
  )
  let onIntent = React.useCallback(overridePriority =>
    switch (preloadData, preloadCode) {
    | (OnIntent, _) => doPreloadDataAndCode(overridePriority)
    | (_, OnIntent) => doPreloadCode(overridePriority)
    | _ => ()
    }
  , (preloadData, preloadCode, doPreloadCode, doPreloadDataAndCode))
  let onRender = React.useCallback(overridePriority =>
    switch (preloadData, preloadCode) {
    | (OnRender, _) => doPreloadDataAndCode(overridePriority)
    | (_, OnRender) => doPreloadCode(overridePriority)
    | _ => ()
    }
  , (preloadData, preloadCode, doPreloadCode, doPreloadDataAndCode))

  // Preload on render if wanted
  React.useEffect(() => {
    onRender(None)
    None
  }, [onRender])

  // Run this on render when SSR:ing if wanted
  if RelaySSRUtils.ssr {
    onRender(None)
  }

  // Sets up an intersection observer for the link if wanted
  React.useEffect(() => {
    switch (linkElement.current, preloadData, preloadCode) {
    | (Value(linkElement), OnInView, _) | (Value(linkElement), _, OnInView) =>
      let observer = IntersectionObserver.make(
        entries => {
          let isVisible =
            entries->Array.some(entry => entry.isIntersecting && entry.target === linkElement)

          switch (hasPreloaded.current, isVisible, preloadData, preloadCode) {
          | (true, _, _, _) => ()
          | (false, true, OnInView, _) =>
            doPreloadDataAndCode(None)
            hasPreloaded.current = true

          | (false, true, _, OnInView) =>
            doPreloadCode(None)
            hasPreloaded.current = true
          | _ => ()
          }
        },
        {
          "threshold": 1.,
          "root": switch targetElementRef {
          | None => None
          | Some({targetElementRef}) => targetElementRef.current->Nullable.toOption
          },
        },
      )

      observer->IntersectionObserver.observe(linkElement)

      Some(
        () => {
          observer->IntersectionObserver.disconnect
        },
      )
    | _ => None
    }
  }, (preloadCode, preloadData, doPreloadCode, doPreloadDataAndCode))

  <a
    ref={ReactDOM.Ref.domRef(linkElement)}
    href=to_
    target={switch browserTarget {
    | Some(#self) => "_self"
    | Some(#blank) => "_blank"
    | None => ""
    }}
    ?title
    ?id
    ?style
    ?className
    ?tabIndex
    onClick={e => {
      changeRoute(e)
      switch onClick {
      | None => ()
      | Some(onClick) => onClick()
      }
    }}
    onMouseDown={_ => {
      // Always start loading on mouse down/touch start regardless of what the config is.
      doPreloadDataAndCode(Some(High))
    }}
    onTouchStart={_ => {
      doPreloadDataAndCode(Some(High))
    }}
    onMouseEnter={_ => onIntent(None)}
    onFocus={_ => onIntent(None)}>
    children
  </a>
}
