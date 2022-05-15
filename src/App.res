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
    <RescriptReactErrorBoundary fallback={_ => React.string("Error!")}>
      <RelayRouter.RouteRenderer
        renderFallback={_ => React.string("Fallback...")}
        renderPending={pending => <PendingIndicatorBar pending />}
      />
    </RescriptReactErrorBoundary>
  </>
}
