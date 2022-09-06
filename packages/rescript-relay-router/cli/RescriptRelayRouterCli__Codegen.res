open RescriptRelayRouterCli__Types
module Utils = RescriptRelayRouterCli__Utils

let wrapInOpt = str => `option<${str}>`

// Param and query param names might collide with eachother, as well as with
// "builtins" we use, like "environment". This helps handle that by checking for
// collisions, letting us refer to safe names where needed.
module SafeParam = {
  type t = Actual(string) | CollisionPrevented({realKey: string, collisionProtectedKey: string})

  let protectedNames = ["environment", "pathParams", "queryParams", "location"]

  type paramType = Param(string) | QueryParam(string)

  let makeSafeParamName = (paramName, ~params) => {
    switch paramName {
    | QueryParam(paramName) =>
      if params->Js.Array2.includes(paramName) || protectedNames->Js.Array2.includes(paramName) {
        CollisionPrevented({realKey: paramName, collisionProtectedKey: "queryParam_" ++ paramName})
      } else {
        Actual(paramName)
      }
    | Param(paramName) =>
      if protectedNames->Js.Array2.includes(paramName) {
        CollisionPrevented({realKey: paramName, collisionProtectedKey: "param_" ++ paramName})
      } else {
        Actual(paramName)
      }
    }
  }

  let getSafeKey = key =>
    switch key {
    | Actual(key) | CollisionPrevented({collisionProtectedKey: key}) => key
    }

  let getOriginalKey = key =>
    switch key {
    | Actual(key) | CollisionPrevented({realKey: key}) => key
    }
}

let getRouteMaker = (route: printableRoute) => {
  let labeledArguments = route.params->Belt.Array.map(paramName => (paramName, "string"))
  let queryParamSerializers = []

  route.queryParams
  ->Js.Dict.entries
  ->Belt.Array.forEach(((paramName, paramType)) => {
    let key = QueryParam(paramName)->SafeParam.makeSafeParamName(~params=route.params)

    let _ =
      labeledArguments->Js.Array2.push((
        key->SafeParam.getSafeKey,
        `option<${Utils.QueryParams.toTypeStr(paramType)}>=?`,
      ))

    let _ =
      queryParamSerializers->Js.Array2.push((
        key,
        paramType->Utils.QueryParams.toSerializer(~variableName=key->SafeParam.getSafeKey),
      ))
  })

  let hasQueryParams = queryParamSerializers->Js.Array2.length > 0
  let shouldAddUnit = hasQueryParams

  let str = ref(
    `@inline
let routePattern = "${route.path->RoutePath.toPattern}"

@live\nlet makeLink = (`,
  )

  let numLabeledArguments = labeledArguments->Js.Array2.length

  labeledArguments->Belt.Array.forEachWithIndex((index, (key, typ)) => {
    str.contents = str.contents ++ `~${key}: ${typ}`
    if index + 1 < numLabeledArguments {
      str.contents = str.contents ++ ", "
    }
  })

  if shouldAddUnit {
    str.contents = str.contents ++ ", ()"
  }

  str.contents = str.contents ++ ") => {\n"

  let urlTemplateString = try route.path->RoutePath.toTemplateString(
    ~pathParams=route.params,
  ) catch {
  | Unmapped_url_part =>
    Js.log(`Route ${route.name->RouteName.getFullRouteName} has invalid path and/or params config.`)
    raise(Unmapped_url_part)
  }

  if hasQueryParams {
    str.contents =
      str.contents ++ `  open RelayRouter.Bindings\n  let queryParams = QueryParams.make()`

    queryParamSerializers->Belt.Array.forEach(((key, serializer)) => {
      str.contents =
        str.contents ++
        `
  switch ${key->SafeParam.getSafeKey} {
    | None => ()
    | Some(${key->SafeParam.getSafeKey}) => queryParams->QueryParams.setParam(~key="${key->SafeParam.getOriginalKey}", ~value=${serializer})
  }\n`
    })
  }

  str.contents =
    str.contents ++ "  RelayRouter.Types.AppRoute({routePattern, url: `" ++ urlTemplateString

  if hasQueryParams {
    str.contents = str.contents ++ "${queryParams->QueryParams.toString}"
  }

  str.contents = str.contents ++ "`})"

  str.contents = str.contents ++ "\n}"
  str.contents
}

let getRouteMakerIfElgible = (route: printableRoute) => {
  switch route.path->RoutePath.elgibleForRouteMaker {
  | true => getRouteMaker(route)
  | false => "\n// Route maker omitted because URL path includes segments that cannot be constructed (usually '*', or a regexp).\n"
  }
}

let getQueryParamAssets = (route: printableRoute) => {
  let queryParamEntries = route.queryParams->Js.Dict.entries

  if queryParamEntries->Js.Array2.length > 0 {
    let str = ref("type queryParams = {")

    queryParamEntries->Belt.Array.forEach(((key, queryParam)) => {
      str.contents =
        str.contents ++ `\n  ${key}: option<${queryParam->Utils.QueryParams.toTypeStr}>,`
    })

    str.contents = str.contents ++ "\n}\n\n"
    str.contents =
      str.contents ++
      `@live\nlet parseQueryParams = (search: string): queryParams => {
  open RelayRouter.Bindings
  let queryParams = QueryParams.parse(search)
  {${queryParamEntries
        ->Belt.Array.map(((key, queryParam)) => {
          `\n    ${key}: queryParams->QueryParams.${queryParam->Utils.queryParamToQueryParamDecoder(
              ~key,
            )}`
        })
        ->Js.Array2.joinWith("")}
  }
}

@live
let makeQueryParams = (${queryParamEntries
        ->Belt.Array.map(((key, queryParam)) => {
          `\n  ~${key}: option<${queryParam->Utils.QueryParams.toTypeStr}>=?, `
        })
        ->Js.Array2.joinWith("")}\n  ()\n) => {${queryParamEntries
        ->Belt.Array.map(((key, _queryParam)) => `\n  ${key}: ${key},`)
        ->Js.Array2.joinWith("")}
}

@live
let setQueryParams = (
  newParams: queryParams,
  ~currentSearch: string, 
  ~navigationMode_=RelayRouter.Types.Push,
  ~removeNotControlledParams=true,
  ~history: RelayRouter.History.t,
  ()
) => {
  open RelayRouter.Bindings

  let queryParams = if removeNotControlledParams {
    QueryParams.make()
  } else {
    QueryParams.parse(currentSearch)
  }

  ${queryParamEntries
        ->Belt.Array.map(((key, queryParam)) => {
          `\n  queryParams->QueryParams.setParamOpt(~key="${key}", ~value=newParams.${key}->Belt.Option.map(${key} => ${queryParam->Utils.QueryParams.toSerializer(
              ~variableName=key,
            )}))`
        })
        ->Js.Array2.joinWith("")}
  
  queryParams->RelayRouter.Internal.setQueryParams(navigationMode_, history)
}

@live
type useQueryParamsReturn = {
  queryParams: queryParams,
  setParams: (
    ~setter: queryParams => queryParams,
    ~onAfterParamsSet: queryParams => unit=?,
    ~navigationMode_: RelayRouter.Types.setQueryParamsMode=?,
    ~removeNotControlledParams: bool=?,
    unit
  ) => unit
}

@live
let useQueryParams = (): useQueryParamsReturn => {
  let {history} = RelayRouter.useRouterContext()
  let {search} = RelayRouter.Utils.useLocation()
  let currentQueryParams = React.useMemo1(() => {
    search->parseQueryParams
  }, [search])

  let searchRef = React.useRef(search)
  let currentQueryParamsRef = React.useRef(currentQueryParams)

  searchRef.current = search
  currentQueryParamsRef.current = currentQueryParams

  {
    queryParams: currentQueryParams, 
    setParams: 
      React.useMemo0(
        () => (
          ~setter,
          ~onAfterParamsSet=?,
          ~navigationMode_=RelayRouter.Types.Push,
          ~removeNotControlledParams=true,
          ()
        ) => {
          let newParams = setter(currentQueryParamsRef.current)

          switch onAfterParamsSet {
            | None => ()
            | Some(onAfterParamsSet) => onAfterParamsSet(newParams)
          }

          newParams
            ->setQueryParams(
              ~currentSearch=searchRef.current, 
              ~navigationMode_, 
              ~removeNotControlledParams, 
              ~history, 
              ()
            )
          },
      )
  }
}`
    str.contents
  } else {
    ""
  }
}

let standardRecordFields = [
  ("environment", "RescriptRelay.Environment.t"),
  ("location", "RelayRouter.History.location"),
]

type routeParamFields = {
  pathParamsRecordFields: array<(string, string)>,
  queryParamsRecordFields: array<(string, string)>,
  allRecordFields: array<(string, string)>,
}

let getRouteParamRecordFields = (route: printableRoute) => {
  let pathParamsRecordFields = []
  let queryParamsRecordFields = []

  route.params->Belt.Array.forEach(param => {
    let _ =
      pathParamsRecordFields->Js.Array2.push((
        Param(param)->SafeParam.makeSafeParamName(~params=route.params)->SafeParam.getSafeKey,
        "string",
      ))
  })

  route.queryParams
  ->Js.Dict.entries
  ->Belt.Array.forEach(((key, param)) => {
    let safeParam = QueryParam(key)->SafeParam.makeSafeParamName(~params=route.params)
    let _ =
      queryParamsRecordFields->Js.Array2.push((
        safeParam->SafeParam.getSafeKey,
        param->Utils.QueryParams.toTypeStr->wrapInOpt,
      ))
  })

  let recordFields =
    standardRecordFields->Js.Array2.concatMany([pathParamsRecordFields, queryParamsRecordFields])

  {
    pathParamsRecordFields: pathParamsRecordFields,
    queryParamsRecordFields: queryParamsRecordFields,
    allRecordFields: recordFields,
  }
}

// Controls whether the generated function is targeting the individual dedicated
// route file, or the general route structure in the generated
// RouteDeclarations.
type makePreparePropsReturnMode = ForInlinedRouteFn | ForDedicatedRouteFile

// This function will take the raw location, path params, query params etc, and
// transform that into prepared (type safe) props for the route render function.
let getMakePrepareProps = (route: printableRoute, ~returnMode) => {
  let hasQueryParams = route.queryParams->Js.Dict.keys->Js.Array2.length > 0
  let params = route.params

  let str = ref(`(. 
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter.History.location,
): prepareProps => {\n`)

  let propsToIgnore = [
    params->Js.Array2.length === 0 ? Some("pathParams") : None,
    hasQueryParams ? None : Some("queryParams"),
  ]

  propsToIgnore
  ->Belt.Array.keepMap(v => v)
  ->Belt.Array.forEach(propName => {
    str.contents = str.contents ++ `  ignore(${propName})\n`
  })

  if returnMode == ForInlinedRouteFn {
    // We preserve type safety by making sure that what we generate type checks,
    // before we cast it to an abstract type (which we do to save bundle size).
    str.contents =
      str.contents ++
      `  let prepareProps: Route__${route.name->RouteName.getFullRouteName}_route.prepareProps = `
  }

  str.contents =
    str.contents ++ "  {
    environment: environment,\n
    location: location,\n"

  params->Belt.Array.forEach(param => {
    str.contents =
      str.contents ++
      `    ${Param(param)
        ->SafeParam.makeSafeParamName(~params)
        ->SafeParam.getSafeKey}: pathParams->Js.Dict.unsafeGet("${param}"),\n`
  })

  if hasQueryParams {
    route.queryParams
    ->Js.Dict.entries
    ->Belt.Array.forEach(((key, param)) => {
      let safeParam = QueryParam(key)->SafeParam.makeSafeParamName(~params=route.params)

      str.contents =
        str.contents ++
        `    ${safeParam->SafeParam.getSafeKey}: queryParams->RelayRouter.Bindings.QueryParams.${param->Utils.queryParamToQueryParamDecoder(
            ~key=safeParam->SafeParam.getOriginalKey,
          )}`
    })
  }

  str.contents = str.contents ++ "  }\n"

  if returnMode == ForInlinedRouteFn {
    str.contents = str.contents ++ `  prepareProps->unsafe_toPrepareProps\n`
  }

  str.contents = str.contents ++ "}"

  str.contents
}

// Creates a unique identifier for the supplied route + the params it has been
// initialized with. Used to identify a route, make sure it can be prepared,
// cached, and cleaned up, etc.
let getMakeRouteKeyFn = (route: printableRoute) => {
  let {pathParamsRecordFields, queryParamsRecordFields} = getRouteParamRecordFields(route)

  `(
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t
): string => {
${if pathParamsRecordFields->Js.Array2.length == 0 {
      "  ignore(pathParams)\n"
    } else {
      ""
    }}${if queryParamsRecordFields->Js.Array2.length == 0 {
      "  ignore(queryParams)\n"
    } else {
      ""
    }}
  "${route.name->RouteName.getFullRouteName}:"
${pathParamsRecordFields
    ->Belt.Array.map(((key, _)) =>
      "    ++ pathParams->Js.Dict.get(\"" ++ key ++ "\")->Belt.Option.getWithDefault(\"\")"
    )
    ->Js.Array2.joinWith("\n")}
${queryParamsRecordFields
    ->Belt.Array.map(((key, _)) =>
      "    ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey(\"" ++
      key ++ "\")->Belt.Option.getWithDefault(\"\")"
    )
    ->Js.Array2.joinWith("\n")}
}

`
}

let getPrepareAssets = (route: printableRoute) => {
  let str = ref(`@live\ntype prepareProps = {\n`)

  let {allRecordFields: recordFields} = getRouteParamRecordFields(route)

  recordFields->Belt.Array.forEach(((key, typ)) => {
    str.contents = str.contents ++ `  ${key}: ${typ},\n`
  })

  str.contents = str.contents ++ "}\n\n"

  str.contents = str.contents ++ `let makeRouteKey = ${getMakeRouteKeyFn(route)}`

  str.contents =
    str.contents ++
    "@live\nlet makePrepareProps = " ++
    route->getMakePrepareProps(~returnMode=ForDedicatedRouteFile) ++ "\n\n"

  str.contents =
    str.contents ++ `@live\ntype renderProps<'prepared> = {
  childRoutes: React.element,
  prepared: 'prepared,\n`

  recordFields->Belt.Array.forEach(((key, typ)) => {
    str.contents = str.contents ++ `  ${key}: ${typ},\n`
  })

  str.contents = str.contents ++ "}\n\n"

  str.contents =
    str.contents ++ `@live\ntype renderers<'prepared> = {
  prepare: prepareProps => 'prepared,
  prepareCode: option<(. prepareProps) => array<RelayRouter.Types.preloadAsset>>,
  render: renderProps<'prepared> => React.element,
}

@obj
external makeRenderer: (
  ~prepare: prepareProps => 'prepared,
  ~prepareCode: prepareProps => array<RelayRouter.Types.preloadAsset>=?,
  ~render: renderProps<'prepared> => React.element,
  unit
) => renderers<'prepared> = ""`

  str.contents
}

let addIndentation = (str, indentation) => {
  Js.String2.repeat("  ", indentation) ++ str
}

let rec getRouteDefinition = (route: printableRoute, ~indentation): string => {
  let routeName = route.name->RouteName.getFullRouteName

  let str = `{
  let routeName = "${routeName}"
  let loadRouteRenderer = () => import__${routeName}->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
  let makePrepareProps = ${route->getMakePrepareProps(~returnMode=ForInlinedRouteFn)}

  {
    path: "${route.path->RoutePath.getPathSegment}",
    name: routeName,
    chunk: "${route.name->RouteName.getRouteRendererName}",
    loadRouteRenderer,
    preloadCode: (
      . ~environment: RescriptRelay.Environment.t,
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
      ~location: RelayRouter.History.location,
    ) => preloadCode(
      ~loadedRouteRenderers,
      ~routeName,
      ~loadRouteRenderer,
      ~environment,
      ~location,
      ~makePrepareProps,
      ~pathParams,
      ~queryParams,
    ),
    prepare: (
      . ~environment: RescriptRelay.Environment.t,
      ~pathParams: Js.Dict.t<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
      ~location: RelayRouter.History.location,
      ~intent: RelayRouter.Types.prepareIntent,
    ) => prepareRoute(
      .
      ~environment,
      ~pathParams,
      ~queryParams,
      ~location,
      ~getPrepared,
      ~loadRouteRenderer,
      ~makePrepareProps,
      ~makeRouteKey=${getMakeRouteKeyFn(route)},
      ~routeName,
      ~intent
    ),
    children: [${route.children
    ->Belt.Array.map(r => getRouteDefinition(r, ~indentation=indentation + 1))
    ->Js.Array2.joinWith(",\n")}],
  }
}`

  str
  ->Js.String2.split("\n")
  ->Js.Array2.map(line => line->addIndentation(indentation))
  ->Js.Array2.joinWith("\n")
}

let getIsRouteActiveFn = (route: RescriptRelayRouterCli__Types.printableRoute) => {
  `@live
let isRouteActive = (~exact: bool=false, {pathname}: RelayRouter.History.location): bool => {
  RelayRouter.Internal.matchPathWithOptions({"path": routePattern, "end": exact}, pathname)->Belt.Option.isSome
}

@live
let useIsRouteActive = (~exact=false, ()) => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo2(() => location->isRouteActive(~exact), (location, exact))
}`
}

let routeNameAsPolyvariant = (route: RescriptRelayRouterCli__Types.printableRoute) =>
  "#" ++ route.name->RouteName.getRouteName

let getActiveSubRouteFn = (route: RescriptRelayRouterCli__Types.printableRoute) => {
  // We count sub routes as anything that's _one_ path element below the current
  // path. So, the parent "todos" with child route "active" is a valid sub route
  // here, but "todos" with the child route "something-else/:id" is not, because
  // it's more than one path element.
  let elgibleChildren =
    route.children->Belt.Array.keep(route =>
      !(route.path->RoutePath.getPathSegment->Js.String2.includes("/"))
    )

  if elgibleChildren->Js.Array2.length == 0 {
    ""
  } else {
    let subRouteType = `[${elgibleChildren
      ->Belt.Array.map(routeNameAsPolyvariant)
      ->Js.Array2.joinWith(" | ")}]`
    `
@live
type subRoute = ${subRouteType}

@live
let useActiveSubRoute = (): option<${subRouteType}> => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo1(() => {
    let {pathname} = location
    ${elgibleChildren
      ->Belt.Array.mapWithIndex((index, child) => {
        let checkStr = `RelayRouter.Internal.matchPath("${child.path->RoutePath.toPattern}", pathname)->Belt.Option.isSome`
        let str = ref("")

        if index == 0 {
          str->Utils.add(`if `)
        } else {
          str->Utils.add(`else if `)
        }

        str->Utils.add(`${checkStr} {\n`)
        str->Utils.add(`      Some(${routeNameAsPolyvariant(child)})\n`)
        str->Utils.add(`    } `)

        str.contents
      })
      ->Js.Array2.joinWith("")}else {
      None
    }
  }, [location])
}`
  }
}

let getActiveRouteAssets = (route: RescriptRelayRouterCli__Types.printableRoute) => {
  let str = ref("")

  // First, add a function + hook that returns whether this path is active or not.
  str->Utils.add(getIsRouteActiveFn(route))

  // Then, add helpers for picking out the active subpath, if there is any.
  str->Utils.add(getActiveSubRouteFn(route))

  str.contents
}
