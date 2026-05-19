open RescriptRelayRouterCli__Types
module Utils = RescriptRelayRouterCli__Utils

let wrapInOpt = str => `option<${str}>`

let indentLines = str =>
  str
  ->String.split("\n")
  ->Array.map(line =>
    switch line == "" {
    | true => line
    | false => `  ${line}`
    }
  )
  ->Array.join("\n")

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

type targetFieldSource =
  | TargetPathParam(printablePathParam)
  | TargetQueryParam(queryParam)

type targetField = {
  fieldName: string,
  originalName: string,
  typ: string,
  source: targetFieldSource,
}

let getTargetFields = (route: printableRoute): array<targetField> => {
  let fields = []

  route.params->Array.forEach(param => {
    let fieldName = Utils.printablePathParamToParamName(param)
    fields->Array.push({
      fieldName,
      originalName: fieldName,
      typ: Utils.printablePathParamToTypeStr(param),
      source: TargetPathParam(param),
    })
  })

  route.queryParams
  ->Dict.toArray
  ->Array.forEach(((queryParamName, queryParam)) => {
    let safeParam = QueryParam(queryParamName)->SafeParam.makeSafeParamName(~params=route.params)
    let queryParamType = queryParam->Utils.QueryParams.toTypeStr

    fields->Array.push({
      fieldName: safeParam->SafeParam.getSafeKey,
      originalName: queryParamName,
      typ: switch queryParam->Utils.queryParamIsOptional {
      | true => queryParamType->wrapInOpt
      | false => queryParamType
      },
      source: TargetQueryParam(queryParam),
    })
  })

  fields
}

let getTargetTypeDefinition = (route: printableRoute) => {
  switch route->getTargetFields {
  | [] => "@live\ntype target = unit\n"
  | fields =>
    `@live
type target = {
${fields->Array.map(field => `  ${field.fieldName}: ${field.typ},`)->Array.join("\n")}
}
`
  }
}

let getPathParamTargetValue = (param: printablePathParam, ~paramName) => {
  let rawValue = `matchedRoute.pathParams->Dict.getUnsafe("${paramName}")`
  switch param {
  | PrintableRegularPathParam({text, pathToCustomModuleWithTypeT}) =>
    `${rawValue}->((${text}RawAsString: string) => (${text}RawAsString :> ${pathToCustomModuleWithTypeT}))`
  | PrintablePathParamWithMatchBranches(_) => `${rawValue}->Obj.magic`
  | PrintableRegularPathParam(_) => rawValue
  }
}

let getTargetRecordLiteral = (route: printableRoute, ~pathParamsSource) => {
  let fields = route->getTargetFields

  switch fields {
  | [] => "()"
  | fields =>
    `{
${fields
      ->Array.map(field => {
        let value = switch field.source {
        | TargetPathParam(param) =>
          switch pathParamsSource {
          | "matchedRoute" => getPathParamTargetValue(param, ~paramName=field.originalName)
          | pathParamsSource => `${pathParamsSource}.${field.fieldName}`
          }
        | TargetQueryParam(_) => `decodedQueryParams.${field.originalName}`
        }
        `  ${field.fieldName}: ${value},`
      })
      ->Array.join("\n")}
}`
  }
}

let getMakeLinkTargetArguments = (route: printableRoute) => {
  route
  ->getTargetFields
  ->Array.map(field =>
    switch field.source {
    | TargetPathParam(_) => `~${field.fieldName}=target.${field.fieldName}`
    | TargetQueryParam(queryParam) =>
      switch queryParam->Utils.queryParamIsOptional {
      | true => `~${field.fieldName}=?target.${field.fieldName}`
      | false => `~${field.fieldName}=target.${field.fieldName}`
      }
    }
  )
  ->Array.join(", ")
}

let getTargetAssets = (route: printableRoute) => {
  let fullRouteName = route.name->RouteName.getFullRouteName
  let hasQueryParams = route.queryParams->Dict.keysToArray->Array.length > 0
  let targetRecordLiteral = route->getTargetRecordLiteral(~pathParamsSource="matchedRoute")
  let targetFromMatchedRoute = `@live
let targetFromMatchedRoute = (
  matchedRoute: RelayRouter.Types.matchedRoute,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
): option<target> =>
  switch matchedRoute.routeName {
  | "${fullRouteName}" =>
${switch hasQueryParams {
    | true => "    let decodedQueryParams = Internal.parseQueryParams(queryParams)\n"
    | false => "    ignore(queryParams)\n"
    }}    Some(${targetRecordLiteral
    ->String.split("\n")
    ->Array.mapWithIndex((line, index) =>
      switch index {
      | 0 => line
      | _ => `    ${line}`
      }
    )
    ->Array.join("\n")})
  | _ => None
  }
`

  let targetToPath = switch route->getTargetFields {
  | [] => `@live\nlet targetToPath = (_target: target): string => makeLink()\n`
  | _ =>
    `@live
let targetToPath = (target: target): string =>
  makeLink(${route->getMakeLinkTargetArguments})
`
  }

  `${route->getTargetTypeDefinition}
${targetFromMatchedRoute}
@live
let targetFromLocation = (location: RelayRouter.History.location): option<target> => {
  let queryParams = RelayRouter.Bindings.QueryParams.parse(location.search)
  switch RelayRouter.Internal.matchPathWithOptions({"path": routePattern, "end": true}, location.pathname) {
  | Some({params}) =>
    targetFromMatchedRoute({
      routeName: "${fullRouteName}",
      routeKey: "",
      pathParams: params,
      slots: [],
      outlet: None,
    }, ~queryParams)
  | None => None
  }
}

${targetToPath}
@live
let targetKey = targetToPath

@live
let targetRouteName = "${fullRouteName}"
`
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

  ") => {\n"->addToStr

  let pathParamNames = route.params->Array.map(Utils.printablePathParamToParamName)
  let pathParamsAsDict = `dict{${pathParamNames
    ->Array.map(paramName => `"${paramName}": (${paramName} :> string)->encodeURIComponent`)
    ->Array.join(",")}}`

  if hasQueryParams {
    `  open RelayRouter.Bindings\n  let queryParams = QueryParams.make()`->addToStr

    queryParamSerializers->Array.forEach(((key, serializer, paramType)) => {
      let serializerStr = `queryParams->QueryParams.${switch paramType {
        | Array(_) => "setParamArray"
        | CustomModule({required: true}) => "setParamOpt"
        | _ => "setParam"
        }}(~key="${key->SafeParam.getOriginalKey}", ~value=${serializer})`

      `
  switch ${key->SafeParam.getSafeKey} {
    | None => ()
    | Some(${key->SafeParam.getSafeKey}) => ${serializerStr}
  }\n`->addToStr
    })
  }

  `  RelayRouter.Bindings.generatePath(routePattern, ${pathParamsAsDict})`->addToStr

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
    ->Dict.toArray
    ->Array.forEach(((queryParamName, queryParam)) => {
      `~${queryParamName}=${Utils.queryParamIsOptional(queryParam)
          ? "?"
          : ""}queryParams.${queryParamName}, `->addToStr
    })

    `)
}
`->addToStr

    `
@live
let useMakeLinkWithPreservedPath = (): ((queryParams => queryParams) => string) => RelayRouter__Internal.useMakeLinkWithPreservedPath(~parseQueryParams=Internal.parseQueryParams, ~applyQueryParams)
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

let getQueryParamTypeDefinition = (route: printableRoute) => {
  let queryParamEntries = route.queryParams->Dict.toArray

  if queryParamEntries->Array.length > 0 {
    let str = ref("type queryParams = {")

    queryParamEntries->Array.forEach(((key, queryParam)) => {
      let isOptional = Utils.queryParamIsOptional(queryParam)
      str.contents =
        str.contents ++
        `\n  ${key}: ${if isOptional {
            "option<"
          } else {
            ""
          }}${queryParam->Utils.QueryParams.toTypeStr}${if isOptional {
            ">"
          } else {
            ""
          }},`
    })

    str.contents = str.contents ++ "\n}\n\n"
    str.contents
  } else {
    ""
  }
}

let getQueryParamAssets = (route: printableRoute) => {
  let queryParamEntries = route.queryParams->Dict.toArray

  if queryParamEntries->Array.length > 0 {
    let queryParamSetters =
      queryParamEntries
      ->Array.map(((key, queryParam)) => {
        switch queryParam {
        | Array(queryParam) =>
          `  queryParams->QueryParams.setParamArrayOpt(~key="${key}", ~value=newParams.${key}->Option.map(${key} => ${key}->Array.map(${key} => ${queryParam->Utils.QueryParams.toSerializer(
              ~variableName=key,
            )})))`
        | CustomModule({required: true}) =>
          `  queryParams->QueryParams.setParamOpt(~key="${key}", ~value=${queryParam->Utils.QueryParams.toSerializer(
              ~variableName=`newParams.${key}`,
            )})`
        | queryParam =>
          `  queryParams->QueryParams.setParamOpt(~key="${key}", ~value=newParams.${key}->Option.map(${key} => ${queryParam->Utils.QueryParams.toSerializer(
              ~variableName=key,
            )}))`
        }
      })
      ->Array.join("\n")

    `@live
let applyQueryParams = (
  queryParams: RelayRouter__Bindings.QueryParams.t,
  ~newParams: queryParams,
) => {
  open RelayRouter__Bindings

${queryParamSetters}
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
  ) => unit
}

@live
let useQueryParams = (): useQueryParamsReturn => {
  let {search: search__} = RelayRouter.Utils.useLocation()
  let queryParams__ = React.useMemo(() => RelayRouter.Bindings.QueryParams.parse(search__), [search__])
${queryParamEntries
      ->Array.map(((key, queryParam)) => {
        `  let ${key} = ${queryParam->Utils.queryParamToQueryParamDecoderInHook(~key)}`
      })
      ->Array.join("\n")}
  let currentQueryParams = React.useMemo(() => {
${queryParamEntries
      ->Array.map(((key, _)) => {
        `    ${key}: ${key}`
      })
      ->Array.join(",\n")}
  }, [search__])

  {
    queryParams: currentQueryParams,
    setParams: RelayRouter__Internal.useSetQueryParams(~parseQueryParams=Internal.parseQueryParams, ~applyQueryParams),
  }
}`
  } else {
    ""
  }
}

type recordField = Spread(string) | KeyValue(string, string)

let standardRecordFields = [
  KeyValue("environment", "RescriptRelay.Environment.t"),
  KeyValue("location", "RelayRouter.History.location"),
]

type routeParamFields = {
  pathParamsRecordFields: array<(string, string)>,
  queryParamsRecordFields: array<(string, string)>,
  allRecordFields: array<recordField>,
}

let getRecordStructureToDecodePathParams = (p: printableRoute, ~paramName="params") => {
  let str = ref("")

  switch p.params {
  | [] => str.contents
  | _ =>
    p.params->Array.forEach(p => {
      str :=
        str.contents ++
        `    ${Utils.printablePathParamToParamName(
            p,
          )}: ${paramName}->Dict.getUnsafe("${Utils.printablePathParamToParamName(p)}")${switch p {
          | PrintableRegularPathParam({text, pathToCustomModuleWithTypeT}) =>
            `->((${text}RawAsString: string) => (${text}RawAsString :> ${pathToCustomModuleWithTypeT}))`
          | PrintablePathParamWithMatchBranches(_) => `->Obj.magic`
          | _ => ""
          }},\n`
    })

    str.contents
  }
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

  let recordFields = standardRecordFields->Array.copy

  if route.params->Array.length > 0 {
    recordFields->Array.push(Spread("pathParams"))
  }

  if route.queryParams->Dict.keysToArray->Array.length > 0 {
    recordFields->Array.push(Spread("queryParams"))
  }

  {
    pathParamsRecordFields,
    queryParamsRecordFields,
    allRecordFields: recordFields,
  }
}

let rec findChildrenPathParams = (route: printableRoute, ~pathParams=Dict.make()) => {
  route.children->Array.forEach(child => {
    child.params->Array.forEach(param => {
      pathParams->Dict.set(
        switch param {
        | PrintableRegularPathParam({text})
        | PrintablePathParamWithMatchBranches({text}) => text
        },
        param,
      )
    })
    let _ = findChildrenPathParams(child, ~pathParams)
  })

  pathParams
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
  let childParams = findChildrenPathParams(route)->Dict.toArray

  let str = ref(`(.
  ~environment: RescriptRelay.Environment.t,
  ~pathParams: dict<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
  ~location: RelayRouter.History.location,
): prepareProps => {\n`)

  let propsToIgnore = [
    params->Array.length === 0 && childParams->Array.length === 0 ? Some("pathParams") : None,
    hasQueryParams ? None : Some("queryParams"),
  ]

  propsToIgnore
  ->Array.filterMap(v => v)
  ->Array.forEach(propName => {
    str.contents = str.contents ++ `  ignore(${propName})\n`
  })

  switch returnMode {
  | ForInlinedRouteFn =>
    // We preserve type safety by making sure that what we generate type checks,
    // before we cast it to an abstract type (which we do to save bundle size).
    str.contents =
      str.contents ++
      `  let prepareProps: Route__${route.name->RouteName.getFullRouteName}_route.Internal.prepareProps = {\n`
  | ForDedicatedRouteFile => str.contents = str.contents ++ "  {\n"
  }

  str.contents =
    str.contents ++ `    environment: environment,
    location: location,\n`

  if childParams->Array.length > 0 {
    str.contents = str.contents ++ "    childParams: Obj.magic(pathParams),\n"
  }

  str.contents =
    str.contents ++ getRecordStructureToDecodePathParams(route, ~paramName="pathParams")

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

  switch returnMode {
  | ForInlinedRouteFn => str.contents = str.contents ++ `  prepareProps->unsafe_toPrepareProps\n`
  | ForDedicatedRouteFile => ()
  }

  str.contents = str.contents ++ "}"

  str.contents
}

// Creates a unique identifier for the supplied route + the params it has been
// initialized with. Used to identify a route, make sure it can be prepared,
// cached, and cleaned up, etc.
let getMakeRouteKeyFn = (route: printableRoute) => {
  let pathParams = route.params->Array.map(Utils.printablePathParamToParamName)
  let queryParams = route.queryParams->Dict.toArray
  let ignoreLines = [
    switch pathParams->Array.length {
    | 0 => Some("  ignore(pathParams)")
    | _ => None
    },
    switch queryParams->Array.length {
    | 0 => Some("  ignore(queryParams)")
    | _ => None
    },
  ]->Array.filterMap(line => line)
  let pathParamLines =
    pathParams->Array.map(key =>
      `  ->RelayRouter.Internal.RouteKey.addPathParam(~name="${key}", ~value=pathParams->Dict.get("${key}")->Option.getOr(""))`
    )
  let queryParamLines = queryParams->Array.map(((key, param)) =>
    switch param {
    | Array(_) =>
      `  ->RelayRouter.Internal.RouteKey.addQueryParamArray(~name="${key}", ~values=queryParams->RelayRouter.Bindings.QueryParams.getArrayParamByKey("${key}"))`
    | _ =>
      `  ->RelayRouter.Internal.RouteKey.addQueryParam(~name="${key}", ~value=queryParams->RelayRouter.Bindings.QueryParams.getParamByKey("${key}"))`
    }
  )
  let bodyLines =
    List.concatMany([
      ignoreLines->List.fromArray,
      list{`  RelayRouter.Internal.RouteKey.make("${route.name->RouteName.getFullRouteName}")`},
      pathParamLines->List.fromArray,
      queryParamLines->List.fromArray,
    ])
    ->List.toArray
    ->Array.join("\n")

  `(
  ~pathParams: dict<string>,
  ~queryParams: RelayRouter.Bindings.QueryParams.t
): string => {
${bodyLines}
}`
}

let getPathParamsTypeDefinition = (route: printableRoute) => {
  let str = ref("")

  switch route.params {
  | [] => ()
  | pathParams =>
    str := str.contents ++ "@live\ntype pathParams = {\n"
    pathParams->Array.forEach(p => {
      str :=
        str.contents ++
        `  ${Utils.printablePathParamToParamName(p)}: ${Utils.printablePathParamToTypeStr(p)},\n`
    })
    str := str.contents ++ "}\n\n"
  }

  str.contents
}
let getUsePathParamsHook = (route: printableRoute) => {
  let str = ref("")

  switch route.params {
  | [] => ()
  | _ =>
    str :=
      str.contents ++ `@live\nlet usePathParams = (~exact=false): option<pathParams> => {
  let {pathname} = RelayRouter.Utils.useLocation()
  switch RelayRouter.Internal.matchPathWithOptions({"path": routePattern, "end": exact}, pathname) {
  | Some({params}) => Some(Obj.magic(params))
  | None => None
  }
}`
  }

  str.contents
}

let getQueryParamParser = (route: printableRoute) => {
  let queryParamEntries = route.queryParams->Dict.toArray

  if queryParamEntries->Array.length > 0 {
    `  let parseQueryParams = (queryParams: RelayRouter.Bindings.QueryParams.t): queryParams => {
    open RelayRouter.Bindings
    {
${queryParamEntries
      ->Array.map(((key, queryParam)) => {
        `      ${key}: queryParams->QueryParams.${queryParam->Utils.queryParamToQueryParamDecoder(
            ~key,
          )}`
      })
      ->Array.join("")}    }
  }

`
  } else {
    ""
  }
}

let getPrepareTypeDefinitions = (route: printableRoute) => {
  let str = ref("")

  let childPathParams = findChildrenPathParams(route)->Dict.toArray
  let {allRecordFields: recordFields} = getRouteParamRecordFields(route)

  switch childPathParams {
  | [] => ()
  | childPathParams =>
    str := str.contents ++ "  @live\n  type childPathParams = {\n"
    childPathParams->Array.forEach(((key, typ)) => {
      str := str.contents ++ `    ${key}: option<${typ->Utils.printablePathParamToTypeStr}>,\n`
    })
    str := str.contents ++ "  }\n\n"
    recordFields->Array.push(KeyValue("childParams", "childPathParams"))
  }

  str := str.contents ++ "  @live\n  type prepareProps = {\n"

  recordFields->Array.forEach(field => {
    str.contents =
      str.contents ++
      switch field {
      | KeyValue(key, typ) => `    ${key}: ${typ},\n`
      | Spread(recordName) => `    ...${recordName},\n`
      }
  })

  str.contents = str.contents ++ "  }\n\n"

  str.contents =
    str.contents ++ `  @live\n  type renderProps<'prepared> = {
    childRoutes: React.element,
    prepared: 'prepared,\n`

  recordFields->Array.forEach(field => {
    str.contents =
      str.contents ++
      switch field {
      | KeyValue(key, typ) => `    ${key}: ${typ},\n`
      | Spread(recordName) => `    ...${recordName},\n`
      }
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
    ->Array.join("\n") ++ "\n"

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
) => Internal.renderers<'prepared> = ""`

  str.contents
}

let addIndentation = (str, indentation) => {
  switch str {
  | "" => ""
  | str => String.repeat("  ", indentation) ++ str
  }
}

let rec getRouteDefinition = (route: printableRoute, ~indentation): string => {
  let routeName = route.name->RouteName.getFullRouteName
  let childrenDefinition = switch route.children {
  | [] => ""
  | children =>
    "\n" ++
    children
    ->Array.map(route => getRouteDefinition(route, ~indentation=indentation + 1))
    ->Array.join(",\n") ++ "\n"
  }

  let str = `{
  let routeName = "${routeName}"
  let loadRouteRenderer = () => (() => import(${routeName}_route_renderer.renderer))->Obj.magic->doLoadRouteRenderer(~routeName, ~loadedRouteRenderers)
  let makePrepareProps = ${route->getMakePrepareProps(~returnMode=ForInlinedRouteFn)}

  {
    path: "${route.path->RoutePath.getPathSegment}",
    name: routeName,
    slots: [${route.slots->Array.map(slot => `"${slot}"`)->Array.join(", ")}],
    outlet: ${switch route.outlet {
    | Some(outlet) => `Some("${outlet}")`
    | None => "None"
    }},
    loadRouteRenderer,
    preloadCode: (
      ~environment: RescriptRelay.Environment.t,
      ~pathParams: dict<string>,
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
      ~environment: RescriptRelay.Environment.t,
      ~pathParams: dict<string>,
      ~queryParams: RelayRouter.Bindings.QueryParams.t,
      ~location: RelayRouter.History.location,
      ~intent: RelayRouter.Types.prepareIntent,
    ) => prepareRoute(
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
    children: [${childrenDefinition}],
  }
}`

  str
  ->String.split("\n")
  ->Array.map(line => line->addIndentation(indentation))
  ->Array.join("\n")
}

let getIsRouteActiveFn = () => {
  `@live
let isRouteActive = (~exact: bool=false, {pathname}: RelayRouter.History.location): bool => {
  RelayRouter.Internal.matchPathWithOptions({"path": routePattern, "end": exact}, pathname)->Option.isSome
}

@live
let useIsRouteActive = (~exact=false) => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo(() => location->isRouteActive(~exact), (location, exact))
}`
}

let routeNameAsPolyvariant = (route: RescriptRelayRouterCli__Types.printableRoute) =>
  "#" ++ route.name->RouteName.getRouteName

let getActiveSubRouteFn = (route: RescriptRelayRouterCli__Types.printableRoute) => {
  // A sub route is any immediate child in the route tree, even if that child
  // path spans multiple URL segments such as "c/:channelSlug".
  let eligibleChildren = route.children

  if eligibleChildren->Array.length == 0 {
    ""
  } else {
    let subRouteType = `[${eligibleChildren
      ->Array.map(routeNameAsPolyvariant)
      ->Array.join(" | ")}]`
    `
@live
type subRoute = ${subRouteType}

@live
let getActiveSubRoute = (location: RelayRouter.History.location): option<${subRouteType}> => {
  let {pathname} = location
  ${eligibleChildren
      ->Array.mapWithIndex((child, index) => {
        let checkStr = `RelayRouter.Internal.matchPath("${child.path->RoutePath.toPattern}", pathname)->Option.isSome`
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
      ->Array.join("")}else {
    None
  }
}

@live
let useActiveSubRoute = (): option<${subRouteType}> => {
  let location = RelayRouter.Utils.useLocation()
  React.useMemo(() => {
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

let getSlotAssets = (route: RescriptRelayRouterCli__Types.printableRoute) => {
  switch route.slots {
  | [] => ""
  | slots =>
    let routeName = route.name->RouteName.getFullRouteName
    `module Slots = {
${slots
      ->Array.map(slotName =>
        `  module ${slotName} = {
    @react.component
    let make = (~fallback=?) =>
      <RelayRouter.Slot routeName="${routeName}" slotName="${slotName}" ?fallback />

    let useHasContent = () =>
      RelayRouter.Slot.useHasContent(~routeName="${routeName}", ~slotName="${slotName}")
  }`
      )
      ->Array.join("\n")}
}
`
  }
}

let getParseRoute = (route: RescriptRelayRouterCli__Types.printableRoute) => {
  let hasQueryParams = route.queryParams->Dict.keysToArray->Array.length > 0
  let hasPathParams = route.params->Array.length > 0
  if hasQueryParams && hasPathParams {
    `
@live
let parseRoute: (
  string,
  ~exact: bool=?,
) => option<(pathParams, queryParams)> = RelayRouter.Internal.parseRoute(
  PathAndQueryParams({
    routePattern,
    parseQueryParams: Internal.parseQueryParams,
  }),
)
\n`
  } else if hasQueryParams {
    `
@live
let parseRoute: (
  string,
  ~exact: bool=?,
) => option<queryParams> = RelayRouter.Internal.parseRoute(
  QueryParams({
    routePattern,
    parseQueryParams: Internal.parseQueryParams,
  }),
)
\n`
  } else if hasPathParams {
    `
@live
let parseRoute: (
  string,
  ~exact: bool=?,
) => option<pathParams> = RelayRouter.Internal.parseRoute(
  PathParams({routePattern: routePattern}),
)
\n`
  } else {
    ""
  }
}

let rec flattenRoutes = (route: printableRoute): array<printableRoute> => {
  let routes = [route]
  route.children->Array.forEach(child => {
    child->flattenRoutes->Array.forEach(route => routes->Array.push(route))
  })
  routes
}

let targetVariantName = (~root: printableRoute, route: printableRoute) => {
  let rootName = root.name->RouteName.getFullRouteName
  let routeName = route.name->RouteName.getFullRouteName

  switch routeName == rootName {
  | true => "Self"
  | false => routeName->String.replace(`${rootName}__`, "")
  }
}

let targetRouteAccessor = (~root: printableRoute, route: printableRoute, ~localName) => {
  let rootName = root.name->RouteName.getFullRouteName
  let routeName = route.name->RouteName.getFullRouteName

  switch routeName == rootName {
  | true => localName
  | false => `${route.name->RouteName.toGeneratedRouteModuleName}.${localName}`
  }
}

let rec getTargetFromLocationChain = (
  routes: list<printableRoute>,
  ~root: printableRoute,
  ~indentation,
) => {
  let indentationStr = "  "->String.repeat(indentation)
  switch routes {
  | list{} => `${indentationStr}None`
  | list{route, ...rest} =>
    let variantName = route->targetVariantName(~root)
    let targetFromLocation = route->targetRouteAccessor(~root, ~localName="targetFromLocation")
    `${indentationStr}switch ${targetFromLocation}(location) {
${indentationStr}| Some(target) => Some(${variantName}(target))
${indentationStr}| None =>
${rest->getTargetFromLocationChain(~root, ~indentation=indentation + 1)}
${indentationStr}}`
  }
}

let getTargetModule = (root: printableRoute) => {
  let routes = root->flattenRoutes
  let variantLines =
    routes
    ->Array.map(route => {
      let variantName = route->targetVariantName(~root)
      let targetType = route->targetRouteAccessor(~root, ~localName="target")
      `  | ${variantName}(${targetType})`
    })
    ->Array.join("\n")

  let fromMatchedRouteCases =
    routes
    ->Array.map(route => {
      let variantName = route->targetVariantName(~root)
      let routeName = route.name->RouteName.getFullRouteName
      let targetFromMatchedRoute =
        route->targetRouteAccessor(~root, ~localName="targetFromMatchedRoute")
      `  | "${routeName}" =>
    ${targetFromMatchedRoute}(matchedRoute, ~queryParams)->Option.map(target =>
      ${variantName}(target)
    )`
    })
    ->Array.join("\n")

  let toPathCases =
    routes
    ->Array.map(route => {
      let variantName = route->targetVariantName(~root)
      let targetToPath = route->targetRouteAccessor(~root, ~localName="targetToPath")
      `  | ${variantName}(target) => ${targetToPath}(target)`
    })
    ->Array.join("\n")

  let routeNameCases =
    routes
    ->Array.map(route => {
      let variantName = route->targetVariantName(~root)
      let routeName = route.name->RouteName.getFullRouteName
      `  | ${variantName}(_) => "${routeName}"`
    })
    ->Array.join("\n")

  let body = `@live
type t =
${variantLines}

let fromMatchedRoute = (
  matchedRoute: RelayRouter.Types.matchedRoute,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
): option<t> =>
  switch matchedRoute.routeName {
${fromMatchedRouteCases}
  | _ => None
  }

let fromEntryWithQueryParams = (
  entry: RelayRouter.Types.currentRouterEntry,
  ~queryParams: RelayRouter.Bindings.QueryParams.t,
): option<t> =>
  switch entry.matchedRoutes->Array.toReversed->Array.get(0) {
  | Some(matchedRoute) => fromMatchedRoute(matchedRoute, ~queryParams)
  | None => None
  }

let fromEntry = (entry: RelayRouter.Types.currentRouterEntry): option<t> =>
  fromEntryWithQueryParams(entry, ~queryParams=entry.queryParams)

let useCurrent = (): option<t> => {
  let router = RelayRouter.useRouterContext()
  let location = RelayRouter.Utils.useLocation()
  let (entry, setEntry) = React.useState(() => router.get())

  React.useEffect(() => {
    let dispose = router.subscribe(nextEntry => setEntry(_ => nextEntry))
    Some(dispose)
  }, [router])

  React.useMemo(() => {
    let queryParams = RelayRouter.Bindings.QueryParams.parse(location.search)
    fromEntryWithQueryParams(entry, ~queryParams)
  }, (entry, location.search))
}

let fromLocation = (location: RelayRouter.History.location): option<t> =>
${routes->List.fromArray->getTargetFromLocationChain(~root, ~indentation=1)}

let toPath = (target: t): string =>
  switch target {
${toPathCases}
  }

let key = toPath

let routeName = (target: t): string =>
  switch target {
${routeNameCases}
  }
`

  `module Target = {
${body->indentLines}
}
`
}
