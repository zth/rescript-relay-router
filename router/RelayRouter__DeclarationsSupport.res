@val external suspend: Js.Promise.t<'any> => unit = "throw"
@val external import_: string => Js.Promise.t<'a> = "import"

exception Route_loading_failed(string)

type prepareProps
type prepared
type renderProps

@val
external unsafe_createRenderProps: (
  {"prepared": prepared},
  {"childRoutes": React.element},
  prepareProps,
) => renderProps = "Object.assign"

external unsafe_asPrepareProps: 'any => prepareProps = "%identity"

module RouteRenderer = {
  type t = {
    prepareCode: option<(. prepareProps) => array<RelayRouterTypes.preloadAsset>>,
    prepare: (. prepareProps) => prepared,
    render: (. renderProps) => React.element,
  }
}

type suspenseEnabledHolder<'thing> = NotInitiated | Pending(Js.Promise.t<'thing>) | Loaded('thing)

type loadedRouteRenderer = suspenseEnabledHolder<RouteRenderer.t>

type preparedContainer = {
  dispose: (. unit) => unit,
  render: RelayRouter.Types.renderRouteFn,
  mutable timeout: option<Js.Global.timeoutId>,
}

type makePrepareProps = (
  . ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter.Bindings.History.location,
) => prepareProps

let loadRouteRenderer = (
  loadFn: unit => Js.Promise.t<RouteRenderer.t>,
  ~routeName,
  ~loadedRouteRenderers,
) => {
  let promise = loadFn()
  loadedRouteRenderers->Belt.HashMap.String.set(routeName, Pending(promise))

  promise->Js.Promise.then_(routeRenderer => {
    loadedRouteRenderers->Belt.HashMap.String.set(routeName, Loaded(routeRenderer))
    Js.Promise.resolve()
  }, _)
}

let preloadCode = (
  ~loadedRouteRenderers,
  ~routeName,
  ~loadRouteRenderer,
  ~makePrepareProps: makePrepareProps,
  ~environment,
  ~pathParams,
  ~queryParams,
  ~location,
) => {
  let apply = (routeRenderer: RouteRenderer.t) => {
    let preparedProps = makePrepareProps(. ~environment, ~pathParams, ~queryParams, ~location)

    switch routeRenderer.prepareCode {
    | Some(prepareCode) => prepareCode(. preparedProps)
    | None => []
    }
  }

  switch loadedRouteRenderers->Belt.HashMap.String.get(routeName) {
  | None | Some(NotInitiated) => loadRouteRenderer()->Js.Promise.then_(() => {
      switch loadedRouteRenderers->Belt.HashMap.String.get(routeName) {
      | Some(Loaded(routeRenderer)) => routeRenderer->apply->Js.Promise.resolve
      | _ =>
        raise(
          Route_loading_failed(
            "Invalid state after loading route renderer. Please report this error.",
          ),
        )
      }
    }, _)
  | Some(Pending(promise)) => promise->Js.Promise.then_(routeRenderer => {
      routeRenderer->apply->Js.Promise.resolve
    }, _)
  | Some(Loaded(routeRenderer)) =>
    Js.Promise.make((~resolve, ~reject as _) => {
      resolve(. apply(routeRenderer))
    })
  }
}
