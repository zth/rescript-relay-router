exception Data_not_mocked_properly

let makeStorybookMockNetworkLayer = () =>
  RescriptRelay.Network.makePromiseBased(~fetchFunction=(_, _, _, _) => {
    raise(Data_not_mocked_properly)
  }, ())

let makeStorybookEnv = (network: RescriptRelay.Network.t) =>
  RelayEnv.makeEnvironmentWithNetwork(
    ~network,
    ~missingFieldHandlers=[
      RescriptRelay.MissingFieldHandler.makeScalarMissingFieldHandler((
        field,
        record,
        args,
        _store,
      ) => {
        Js.log2("missing scalar field", {"field": field, "record": record, "args": args})
        None
      }),
      RescriptRelay.MissingFieldHandler.makeLinkedMissingFieldHandler((
        field,
        record,
        args,
        _store,
      ) => {
        Js.log2("missing linked field", {"field": field, "record": record, "args": args})
        None->Js.Nullable.fromOption
      }),
      RescriptRelay.MissingFieldHandler.makePluralLinkedMissingFieldHandler((
        field,
        record,
        args,
        _store,
      ) => {
        Js.log2("missing plural linked field", {"field": field, "record": record, "args": args})
        None->Js.Nullable.fromOption
      }),
    ],
    (),
  )

module StorybookRelayEnvMockData = {
  @react.component @live
  let make = (~children, ~initWithEnvironment) => {
    let (inited, setInited) = React.useState(() => false)
    let environment = React.useMemo0(() => makeStorybookMockNetworkLayer()->makeStorybookEnv)

    React.useEffect1(() => {
      initWithEnvironment(environment)
      setInited(_ => true)
      None
    }, [environment])

    switch inited {
    | false => React.null
    | true =>
      <RescriptReactErrorBoundary
        fallback={err => {
          Js.log(err)
          React.string("Seems like you did not mock your data properly. Mock it and try again.")
        }}>
        <RescriptRelay.Context.Provider environment> {children} </RescriptRelay.Context.Provider>
      </RescriptReactErrorBoundary>
    }
  }
}
