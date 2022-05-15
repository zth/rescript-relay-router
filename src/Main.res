@react.component
let make = (~environment, ~routerContext) => {
  <RescriptRelay.Context.Provider environment>
    <RelayRouter.Provider value={routerContext}>
      <React.Suspense fallback={React.string("Loading...")}>
        <RescriptReactErrorBoundary fallback={_ => React.string("Error!")}>
          <App />
        </RescriptReactErrorBoundary>
      </React.Suspense>
    </RelayRouter.Provider>
  </RescriptRelay.Context.Provider>
}
