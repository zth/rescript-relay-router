type history

@val
external history: history = "window.history"

@set
external setScrollRestoration: (history, [#manual | #auto]) => unit = "scrollRestoration"

if !RelaySSRUtils.ssr {
  history->setScrollRestoration(#manual)
}

@react.component
let make = (~environment, ~routerContext) => {
  <RescriptRelay.Context.Provider environment>
    <RelayRouter.Provider value={routerContext}>
      <React.Suspense fallback={React.string("Loading...")}>
        <RescriptReactErrorBoundary fallback={_ => {<div> {React.string("Error!")} </div>}}>
          <RelayRouter.RouteRenderer
            // This renders all the time, and when there's a pending navigation (pending via React concurrent mode), pending will be `true`
            renderPending={pending => <PendingIndicatorBar pending />}
          />
        </RescriptReactErrorBoundary>
      </React.Suspense>
    </RelayRouter.Provider>
  </RescriptRelay.Context.Provider>
}
