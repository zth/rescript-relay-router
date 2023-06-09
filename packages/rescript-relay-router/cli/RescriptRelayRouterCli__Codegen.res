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
    let paramNames = params->Array.map(Utils.printablePathParamToParamName)
    switch paramName {
    | QueryParam(paramName) =>
      if paramNames->Array.includes(paramName) || protectedNames->Array.includes(paramName) {
        CollisionPrevented({realKey: paramName, collisionProtectedKey: "queryParam_" ++ paramName})
      } else {
        Actual(paramName)
      }
    | Param(paramName) =>
      if protectedNames->Array.includes(paramName) {
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

let getRouteMakerAndAssets = (route: printableRoute) => {
  let labeledArguments =
    route.params->Array.map(param => (
      Utils.printablePathParamToParamName(param),
      Utils.printablePathParamToTypeStr(param),
    ))
  let queryParamSerializers = []

  route.queryParams
  ->Dict.toArray
  ->Array.forEach(((paramName, paramType)) => {
    let key = QueryParam(paramName)->SafeParam.makeSafeParamName(~params=route.params)

    labeledArguments->Array.push((
      key->SafeParam.getSafeKey,
      `option<${Utils.QueryParams.toTypeStr(paramType)}>=?`,
    ))

    queryParamSerializers->Array.push((
      key,
      paramType->Utils.QueryParams.toSerializer(~variableName=key->SafeParam.getSafeKey),
      paramType,
    ))
  })

  let hasQueryParams = queryParamSerializers->Array.length > 0
  let shouldAddUnit = hasQueryParams

  let str = ref(
    `@inline
let routePattern = "${route.path->RoutePath.toPattern}"

@live\nlet makeLink = (`,
  )

  let addToStr = s => str := str.contents ++ s

  let numLabeledArguments = labeledArguments->Array.length

  labeledArguments->Array.forEachWithIndex(((key, typ), index) => {
    `~${key}: ${typ}`->addToStr
    if index + 1 < numLabeledArguments {
      ", "->addToStr
    }
  })

  if shouldAddUnit {
    ", ()"->addToStr
  }

  ") => {\n"->addToStr

  let pathParamNames = route.params->Array.map(Utils.printablePathParamToParamName)
  let pathParamsAsJsDict = `Js.Dict.fromArray([${pathParamNames
    ->Array.map(paramName =>
      `("${paramName}", (${paramName} :> string)->Js.Global.encodeURIComponent)`
    )
    ->Array.joinWith(",")}])`

  if hasQueryParams {
    `  open RelayRouter.Bindings\n  let queryParams = QueryParams.make()`->addToStr

    queryParamSerializers->Array.forEach(((key, serializer, paramType)) => {
      `
  switch ${key->SafeParam.getSafeKey} {
    | None => ()
    | Some(${key->SafeParam.getSafeKey}) => queryParams->QueryParams.${switch paramType {
        | Array(_) => "setParamArray"
        | _ => "setParam"
        }}(~key="${key->SafeParam.getOriginalKey}", ~value=${serializer})
  }\n`->addToStr
    })
  }

  `  RelayRouter.Bindings.generatePath(routePattern, ${pathParamsAsJsDict})`->addToStr

  if hasQueryParams {
    " ++ queryParams->QueryParams.toString"->addToStr
  }

  "\n}"->addToStr

  if hasQueryParams {
    `
@live
let makeLinkFromQueryParams = (`->addToStr
    route.params->Array.forEach(p => {
      `~${Utils.printablePathParamToParamName(p)}: ${Utils.printablePathParamToTypeStr(
          p,
        )}, `->addToStr
    })

    `queryParams: queryParams) => {
  makeLink(`->addToStr
    route.params->Array.forEach(p => {
      `~${Utils.printablePathParamToParamName(p)}, `->addToStr
    })

    route.queryParams
    ->Dict.keysToArray
    ->Array.forEach(queryParamName => {
      `~${queryParamName}=?queryParams.${queryParamName}, `->addToStr
    })

    `())
}
`->addToStr

    `
@live
let useMakeLinkWithPreservedPath = () => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo1(() => {
    (makeNewQueryParams: queryParams => queryParams) => {
      let newQueryParams = location.search->parseQueryParams->makeNewQueryParams
      open RelayRouter.Bindings
      let queryParams = location.search->QueryParams.parse
      queryParams->applyQueryParams(~newParams=newQueryParams)
      location.pathname ++ queryParams->QueryParams.toString
    }
  }, [location.search])
}
`->addToStr
  }

  route.params->Array.forEach(p => {
    switch p {
    | PrintableRegularPathParam(_) => ()
    | PrintablePathParamWithMatchBranches(_) as p =>
      `\n
@live
type pathParam_${Utils.printablePathParamToParamName(p)} = ${Utils.printablePathParamToTypeStr(
          p,
        )}`->addToStr
    }
  })
  str.contents
}

let getQueryParamAssets = (route: printableRoute) => {
  let queryParamEntries = route.queryParams->Dict.toArray

  if queryParamEntries->Array.length > 0 {
    let str = ref("type queryParams = {")

    queryParamEntries->Array.forEach(((key, queryParam)) => {
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
        ->Array.map(((key, queryParam)) => {
          `\n    ${key}: queryParams->QueryParams.${queryParam->Utils.queryParamToQueryParamDecoder(
              ~key,
            )}`
        })
        ->Array.joinWith("")}
  }
}

@live
let makeQueryParams = (${queryParamEntries
        ->Array.map(((key, queryParam)) => {
          `\n  ~${key}: option<${queryParam->Utils.QueryParams.toTypeStr}>=?, `
        })
        ->Array.joinWith("")}\n  ()\n) => {${queryParamEntries
        ->Array.map(((key, _queryParam)) => `\n  ${key}: ${key},`)
        ->Array.joinWith("")}
}

@live
let applyQueryParams = (
  queryParams: RelayRouter__Bindings.QueryParams.t,
  ~newParams: queryParams,
) => {
  open RelayRouter__Bindings

  ${queryParamEntries
        ->Array.map(((key, queryParam)) => {
          switch queryParam {
          | Array(queryParam) =>
            `\n  queryParams->QueryParams.setParamArrayOpt(~key="${key}", ~value=newParams.${key}->Belt.Option.map(${key} => ${key}->Belt.Array.map(${key} => ${queryParam->Utils.QueryParams.toSerializer(
                ~variableName=key,
              )})))`
          | queryParam =>
            `\n  queryParams->QueryParams.setParamOpt(~key="${key}", ~value=newParams.${key}->Belt.Option.map(${key} => ${queryParam->Utils.QueryParams.toSerializer(
                ~variableName=key,
              )}))`
          }
        })
        ->Array.joinWith("")}
}

@live
type useQueryParamsReturn = {
  queryParams: queryParams,
  setParams: (
    ~setter: queryParams => queryParams,
    ~onAfterParamsSet: queryParams => unit=?,
    ~navigationMode_: RelayRouter.Types.setQueryParamsMode=?,
    ~removeNotControlledParams: bool=?,
    ~shallow: bool=?,
    unit
  ) => unit
}

@live
let useQueryParams = (): useQueryParamsReturn => {
  let internalSetQueryParams = RelayRouter__Internal.useSetQueryParams()
  let {search} = RelayRouter.Utils.useLocation()
  let currentQueryParams = React.useMemo1(() => {
    search->parseQueryParams
  }, [search])

  let setParams = (
    ~setter,
    ~onAfterParamsSet=?,
    ~navigationMode_=RelayRouter.Types.Push,
    ~removeNotControlledParams=true,
    ~shallow=true,
    (),
  ) => {
    let newParams = setter(currentQueryParams)

    switch onAfterParamsSet {
    | None => ()
    | Some(onAfterParamsSet) => onAfterParamsSet(newParams)
    }

    internalSetQueryParams({
      applyQueryParams: applyQueryParams(~newParams, ...),
      currentSearch: search,
      navigationMode_: navigationMode_,
      removeNotControlledParams: removeNotControlledParams,
      shallow: shallow,
    })
  }

  {
    queryParams: currentQueryParams,
    setParams: React.useMemo2(
      () => setParams,
      (search, currentQueryParams),
    ),
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

  route.params->Array.forEach(param => {
    pathParamsRecordFields->Array.push((
      Param(Utils.printablePathParamToParamName(param))
      ->SafeParam.makeSafeParamName(~params=route.params)
      ->SafeParam.getSafeKey,
      Utils.printablePathParamToTypeStr(param),
    ))
  })

  route.queryParams
  ->Dict.toArray
  ->Array.forEach(((key, param)) => {
    let safeParam = QueryParam(key)->SafeParam.makeSafeParamName(~params=route.params)

    queryParamsRecordFields->Array.push((
      safeParam->SafeParam.getSafeKey,
      param->Utils.QueryParams.toTypeStr->wrapInOpt,
    ))
  })

  let recordFields =
    standardRecordFields->Array.concatMany([pathParamsRecordFields, queryParamsRecordFields])

  {
    pathParamsRecordFields,
    queryParamsRecordFields,
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
  let hasQueryParams = route.queryParams->Dict.keysToArray->Array.length > 0
  let params = route.params

  let str = ref(`(. 
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: Js.Dict.t<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter.History.location,
): prepareProps => {\n`)

  let propsToIgnore = [
    params->Array.length === 0 ? Some("pathParams") : None,
    hasQueryParams ? None : Some("queryParams"),
  ]

  propsToIgnore
  ->Array.filterMap(v => v)
  ->Array.forEach(propName => {
    str.contents = str.contents ++ `  ignore(${propName})\n`
  })

  if returnMode == ForInlinedRouteFn {
    // We preserve type safety by making sure that what we generate type checks,
    // before we cast it to an abstract type (which we do to save bundle size).
    str.contents =
      str.contents ++
      `  let prepareProps: Route__${route.name->RouteName.getFullRouteName}_route.Internal.prepareProps = `
  }

  str.contents =
    str.contents ++ "  {
    environment: environment,\n
    location: location,\n"

  params->Array.forEach(param => {
    str.contents =
      str.contents ++
      `    ${Param(Utils.printablePathParamToParamName(param))
        ->SafeParam.makeSafeParamName(~params)
        ->SafeParam.getSafeKey}: pathParams->Js.Dict.unsafeGet("${Utils.printablePathParamToParamName(
          param,
        )}")${switch param {
        | PrintablePathParamWithMatchBranches(_) => "->Obj.magic"
        | _ => ""
        }},\n`
  })

  if hasQueryParams {
    route.queryParams
    ->Dict.toArray
    ->Array.forEach(((key, param)) => {
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
${if pathParamsRecordFields->Array.length == 0 {
      "  ignore(pathParams)\n"
    } else {
      ""
    }}${if queryParamsRecordFields->Array.length == 0 {
      "  ignore(queryParams)\n"
    } else {
      ""
    }}
  "${route.name->RouteName.getFullRouteName}:"
${pathParamsRecordFields
    ->Array.map(((key, _)) =>
      "    ++ pathParams->Js.Dict.get(\"" ++ key ++ "\")->Belt.Option.getWithDefault(\"\")"
    )
    ->Array.joinWith("\n")}
${queryParamsRecordFields
    ->Array.map(((key, _)) =>
      "    ++ queryParams->RelayRouter.Bindings.QueryParams.getParamByKey(\"" ++
      key ++ "\")->Belt.Option.getWithDefault(\"\")"
    )
    ->Array.joinWith("\n")}
}

`
}

let getPrepareTypeDefinitions = (route: printableRoute) => {
  let str = ref(`  @live\n  type prepareProps = {\n`)

  let {allRecordFields: recordFields} = getRouteParamRecordFields(route)

  recordFields->Array.forEach(((key, typ)) => {
    str.contents = str.contents ++ `    ${key}: ${typ},\n`
  })

  str.contents = str.contents ++ "  }\n\n"

  str.contents =
    str.contents ++ `  @live\n  type renderProps<'prepared> = {
    childRoutes: React.element,
    prepared: 'prepared,\n`

  recordFields->Array.forEach(((key, typ)) => {
    str.contents = str.contents ++ `    ${key}: ${typ},\n`
  })

  str.contents = str.contents ++ "  }\n\n"

  str.contents =
    str.contents ++ `  @live\n  type renderers<'prepared> = {
    prepare: prepareProps => 'prepared,
    prepareCode: option<(. prepareProps) => array<RelayRouter.Types.preloadAsset>>,
    render: renderProps<'prepared> => React.element,
  }
`

  str.contents =
    str.contents ++
    "  @live\n  let makePrepareProps = " ++
    route
    ->getMakePrepareProps(~returnMode=ForDedicatedRouteFile)
    // Proper indentation
    ->String.split("\n")
    ->Array.mapWithIndex((l, index) => index === 0 ? l : "  " ++ l)
    ->Array.joinWith("\n") ++ "\n\n"

  str.contents
}

let getPrepareAssets = () => {
  let str = ref("")

  str.contents =
    str.contents ++ `@obj
external makeRenderer: (
  ~prepare: Internal.prepareProps => 'prepared,
  ~prepareCode: Internal.prepareProps => array<RelayRouter.Types.preloadAsset>=?,
  ~render: Internal.renderProps<'prepared> => React.element,
  unit
) => Internal.renderers<'prepared> = ""`

  str.contents
}

let addIndentation = (str, indentation) => {
  String.repeat("  ", indentation) ++ str
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
    ->Array.map(r => getRouteDefinition(r, ~indentation=indentation + 1))
    ->Array.joinWith(",\n")}],
  }
}`

  str
  ->String.split("\n")
  ->Array.map(line => line->addIndentation(indentation))
  ->Array.joinWith("\n")
}

let getIsRouteActiveFn = () => {
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
    route.children->Array.filter(route =>
      !(route.path->RoutePath.getPathSegment->String.includes("/"))
    )

  if elgibleChildren->Array.length == 0 {
    ""
  } else {
    let subRouteType = `[${elgibleChildren
      ->Array.map(routeNameAsPolyvariant)
      ->Array.joinWith(" | ")}]`
    `
@live
type subRoute = ${subRouteType}

@live
let getActiveSubRoute = (location: RelayRouter.History.location): option<${subRouteType}> => {
  let {pathname} = location
  ${elgibleChildren
      ->Array.mapWithIndex((child, index) => {
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
      ->Array.joinWith("")}else {
    None
  }
}

@live
let useActiveSubRoute = (): option<${subRouteType}> => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo1(() => {
    getActiveSubRoute(location)
  }, [location])
}`
  }
}

let getActiveRouteAssets = (route: RescriptRelayRouterCli__Types.printableRoute) => {
  let str = ref("")

  // First, add a function + hook that returns whether this path is active or not.
  str->Utils.add(getIsRouteActiveFn())

  // Then, add helpers for picking out the active subpath, if there is any.
  str->Utils.add(getActiveSubRouteFn(route))

  str.contents
}
