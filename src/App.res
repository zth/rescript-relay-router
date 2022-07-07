type history

@val
external history: history = "window.history"

@set
external setScrollRestoration: (history, [#manual | #auto]) => unit = "scrollRestoration"

if !RelaySSRUtils.ssr {
  history->setScrollRestoration(#manual)
}

@react.component
let make = () => {
  <>
    <RescriptReactErrorBoundary
      fallback={_ => {
        <div> {React.string("Error!")} </div>
      }}>
      <RelayRouter.RouteRenderer renderPending={pending => <PendingIndicatorBar pending />} />
    </RescriptReactErrorBoundary>
  </>
}
