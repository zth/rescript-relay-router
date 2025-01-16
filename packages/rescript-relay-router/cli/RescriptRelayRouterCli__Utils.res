open RescriptRelayRouterCli__Types
open RescriptRelayRouterCli__Bindings

exception Invalid_config(string)

module Config: {
  type t = config

  let load: unit => t
  let exists: unit => bool
} = {
  type t = config

  let resolveFullPath = (path, ~filepath) => Path.resolve([Path.dirname(filepath), path])

  let load = () => {
    let config = switch CosmiConfig.make()->CosmiConfig.search {
    | Some({config: Some(config), filepath}) => {
        let resolveFullPath = resolveFullPath(~filepath, ...)

        let routesFolderPath = switch config->Dict.get("routesFolderPath") {
        | Some(routesFolderPath) => routesFolderPath->resolveFullPath
        | None =>
          raise(
            Invalid_config(
              "You must set 'routesFolderPath', a relative path to where your routing code will be located.",
            ),
          )
        }

        {
          generatedPath: config
          ->Dict.get("generatedPath")
          ->Option.getOr(Path.join([routesFolderPath, "__generated__"]))
          ->resolveFullPath,
          routesFolderPath,
          // TODO: This won't work for monorepo setups etc where the ReScript
          // lib dir isn't at the same level as the router config file. Fix
          // eventually.
          rescriptLibFolderPath: Path.join([Path.dirname(filepath), "lib", "bs"]),
        }
      }

    | _ =>
      raise(
        Invalid_config(
          "Could not find router config. Please make sure you've defined a router config either in 'rescriptRelayRouter' in package.json, rescriptRelayRouter.json, or in rescriptRelayRouter.config.js/rescriptRelayRouter.config.cjs",
        ),
      )
    }

    if !(config.generatedPath->Fs.existsSync) {
      Console.log("Folder for generatedPath not found, creating...")
      config.generatedPath->Fs.mkdirRecursiveSync
    }

    if !(config.routesFolderPath->Fs.existsSync) {
      Console.log("Folder for routesFolderPath not found, creating...")
      config.routesFolderPath->Fs.mkdirRecursiveSync
    }

    config
  }

  let exists = () => CosmiConfig.make()->CosmiConfig.search->Option.isSome
}

module QueryParams = {
  // Stringify a query param type.
  let rec toTypeStr = queryParam => {
    switch queryParam {
    | String => "string"
    | Boolean => "bool"
    | Int => "int"
    | Float => "float"
    | Array(inner) => "array<" ++ toTypeStr(inner) ++ ">"
    | CustomModule({moduleName}) => moduleName ++ ".t"
    }
  }

  // Prints a serializer for a typed/decoded query param.
  let toSerializer = (queryParam, ~variableName) => {
    switch queryParam {
    | String => variableName
    | Boolean => `switch ${variableName} { | true => "true" | false => "false" }`
    | Int => `Int.toString(${variableName})`
    | Float => `Float.toString(${variableName})`
    | CustomModule({moduleName, required: true}) =>
      `${variableName}->${moduleName}.serialize === ${moduleName}.defaultValue->${moduleName}.serialize ? None : ${variableName}->${moduleName}.serialize->Some`
    | CustomModule({moduleName}) => `${variableName}->${moduleName}.serialize`
    | Array(inner) =>
      switch inner {
      | Array(_)
      | String => variableName
      | Boolean =>
        `${variableName}->Array.map(bool => switch bool { | true => "true" | false => "false" })`
      | Int => `${variableName}->Array.map(Int.toString)`
      | Float => `${variableName}->Array.map(Float.toString)`
      | CustomModule({moduleName}) =>
        `${variableName}->Array.map(value => value->${moduleName}.serialize)`
      }
    }
  }

  // Prints a parser for a typed query param.
  let toParser = (queryParam, ~variableName) => {
    switch queryParam {
    | String => `Some(${variableName})`
    | Boolean =>
      `switch ${variableName} {
      | "true" => Some(true)
      | "false" => Some(false)
      | _ => None
      }`
    | Int => `Int.fromString(${variableName})`
    | Float => `Float.fromString(${variableName})`
    | CustomModule({moduleName}) => `${variableName}->${moduleName}.parse`
    | Array(inner) =>
      switch inner {
      | Array(_)
      | String => variableName
      | Boolean =>
        `${variableName}->Array.map(value => switch value {
      | "true" => Some(true)
      | "false" => Some(false)
      | _ => None
      })`
      | Int => `${variableName}->Array.map(Int.fromString)`
      | Float => `${variableName}->Array.map(Float.fromString)`
      | CustomModule({moduleName}) =>
        `${variableName}->Array.map(value => value->${moduleName}.parse)`
      }
    }
  }
}

let pathInRoutesFolder = (~config, ~fileName="") => Path.join([config.routesFolderPath, fileName])

let pathInGeneratedFolder = (~config, ~fileName="") => Path.join([config.generatedPath, fileName])

let fromRendererFileName = rendererName => rendererName->String.replace("_route_renderer.res", "")

let toRendererFileName = rendererName => rendererName ++ "_route_renderer.res"

let printablePathParamToTypeStr = p =>
  switch p {
  | PrintableRegularPathParam({?pathToCustomModuleWithTypeT}) =>
    pathToCustomModuleWithTypeT->Option.getOr("string")
  | PrintablePathParamWithMatchBranches({matchArms}) =>
    `[${matchArms->Array.map(b => `#"${b}"`)->Array.join(" | ")}]`
  }

let printablePathParamToParamName = p =>
  switch p {
  | PrintableRegularPathParam({text}) => text
  | PrintablePathParamWithMatchBranches({text}) => text
  }

let rec rawRouteToMatchable = (route: printableRoute): routeForCliMatching => {
  path: route.path->RoutePath.getPathSegment,
  params: route.params->Array.map(printablePathParamToParamName),
  name: route.name->RouteName.getRouteName,
  fullName: route.name->RouteName.getFullRouteName,
  queryParams: route.queryParams,
  children: route.children->Array.map(rawRouteToMatchable),
  sourceFile: route.sourceFile,
}

type routeMatchCli = {
  params: dict<string>,
  route: RescriptRelayRouterCli__Types.routeForCliMatching,
}

@module("../src/vendor/react-router.js") @return(nullable)
external matchRoutesCli: (
  array<RescriptRelayRouterCli__Types.routeForCliMatching>,
  {"pathname": string, "hash": string, "search": string, "state": JSON.t},
) => option<array<routeMatchCli>> = "matchRoutes"

let rec routeChildrenToPrintable = (routeChildren: array<routeChild>): array<printableRoute> => {
  let routes = []
  routeChildren->Array.forEach(child => mapRouteChild(child, ~routes))
  routes
}
and mapRouteChild = (child, ~routes) => {
  switch child {
  | Include({content}) => content->Array.forEach(child => mapRouteChild(child, ~routes))
  | RouteEntry(routeEntry) => routes->Array.push(parsedToPrintable(routeEntry))
  }
}
and parsedToPrintable = (routeEntry: routeEntry): printableRoute => {
  name: routeEntry.name,
  path: routeEntry.routePath,
  params: routeEntry.pathParams->Array.map(p =>
    switch p {
    | PathParam({text, ?pathToCustomModuleWithTypeT}) =>
      PrintableRegularPathParam({text: text.text, ?pathToCustomModuleWithTypeT})
    | PathParamWithMatchBranches({text, matchArms}) =>
      PrintablePathParamWithMatchBranches({text: text.text, matchArms})
    }
  ),
  children: routeEntry.children->Option.getOr([])->routeChildrenToPrintable,
  queryParams: routeEntry.queryParams
  ->Array.map(({name, queryParam: (_loc, queryParam)}) => (name.text, queryParam))
  ->Dict.fromArray,
  sourceFile: routeEntry.sourceFile,
}

exception Decode_error(RescriptRelayRouterCli__Types.routeStructure)

let readRouteStructure = (config): (
  array<printableRoute>,
  dict<(RescriptRelayRouterCli__Types.printableRoute, List.t<string>)>,
) => {
  let {
    errors,
    result,
  } as routeStructure = RescriptRelayRouterCli__Parser.readRouteStructure(
    ~config,
    ~getRouteFileContents=fileName => {
      try {
        Ok(Fs.readFileSync(pathInRoutesFolder(~config, ~fileName)))
      } catch {
      | Exn.Error(exn) => Error(exn)
      }
    },
  )

  if errors->Array.length > 0 {
    raise(Decode_error(routeStructure))
  }

  let printable = routeChildrenToPrintable(result)
  let routeNames = Dict.make()

  let rec extractRoutes = (routes: array<printableRoute>) => {
    routes->Array.forEach(route => {
      routeNames->Dict.set(route.name->RouteName.getFullRouteName, (route, list{}))
      route.children->extractRoutes
    })
  }

  extractRoutes(printable)

  (printable, routeNames)
}

let ensureRouteStructure = pathToRoutesFolder => {
  let routesFolderPath = [pathToRoutesFolder]->Path.resolve
  let generatedPath = Path.join([routesFolderPath, "../__generated__"])

  if !Fs.existsSync(routesFolderPath) {
    Fs.mkdirSync(routesFolderPath)
    Console.log("[init] Routes folder did not exist. Created it at '" ++ routesFolderPath ++ "'.")
  }

  if !Fs.existsSync(generatedPath) {
    Fs.mkdirSync(generatedPath)
  }
}

let printIndentation = (str, indentation) => {
  str.contents = str.contents ++ "  "->String.repeat(indentation)
}

let add = (str, s) => {
  str.contents = str.contents ++ s
}

let rec printNestedRouteModules = (route: printableRoute, ~indentation): string => {
  let moduleName = route.name->RouteName.getRouteName
  let str = ref("")
  let strEnd = ref("")

  str->printIndentation(indentation)
  str->add(`/** [See route renderer](./${route.name->RouteName.getRouteRendererFileName})*/\n`)

  str->printIndentation(indentation)
  str->add(`module ${moduleName} = {\n`)
  str->printIndentation(indentation + 1)
  str->add(`module Route = ${route.name->RouteName.toGeneratedRouteModuleName}\n`)

  strEnd->printIndentation(indentation)
  strEnd->add("}\n")

  route.children->Array.forEach(route => {
    str->add(route->printNestedRouteModules(~indentation=indentation + 1))
  })

  "\n" ++
  str.contents ++ {
    let contents = strEnd.contents->String.split("\n")
    contents->Array.reverse
    contents->Array.join("\n")
  }
}

let queryParamToQueryParamDecoder = (param, ~key) => {
  switch param {
  | Array(param) =>
    `getArrayParamByKey("${key}")->Option.map(value => value->Array.filterMap(value => ${param->QueryParams.toParser(
        ~variableName="value",
      )})),\n`
  | CustomModule({required: true, moduleName}) =>
    `getParamByKey("${key}")->Option.flatMap(value => ${param->QueryParams.toParser(
        ~variableName="value",
      )})->Option.getOr(${moduleName}.defaultValue),\n`
  | param =>
    `getParamByKey("${key}")->Option.flatMap(value => ${param->QueryParams.toParser(
        ~variableName="value",
      )}),\n`
  }
}

let queryParamToQueryParamDecoderInHook = (param, ~key) => {
  switch param {
  | Array(param) =>
    `{
    let param = queryParams__->RelayRouter.Bindings.QueryParams.getArrayParamByKey("${key}")
    React.useMemo(() => param->Option.map(value => value->Array.filterMap(value => ${param->QueryParams.toParser(
        ~variableName="value",
      )})), [param->Option.getOr([])->Array.join(" | ")])
  }`
  | CustomModule({required: true, moduleName}) =>
    `{
    let param = queryParams__->RelayRouter.Bindings.QueryParams.getParamByKey("${key}")
    React.useMemo(() => param->Option.flatMap(value => ${param->QueryParams.toParser(
        ~variableName="value",
      )})->Option.getOr(${moduleName}.defaultValue), [param])
  }`
  | param =>
    `{
    let param = queryParams__->RelayRouter.Bindings.QueryParams.getParamByKey("${key}")
    React.useMemo(() => param->Option.flatMap(value => ${param->QueryParams.toParser(
        ~variableName="value",
      )}), [param])
  }`
  }
}

let maybePluralize = (text, ~count) =>
  text ++ if count == 1 {
    ""
  } else {
    "s"
  }

let rec queryParamIsOptional = (qp: queryParam) =>
  switch qp {
  | CustomModule({required: true}) => false
  | Array(inner) => queryParamIsOptional(inner)
  | _ => true
  }
