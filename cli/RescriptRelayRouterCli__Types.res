@@warning(`-30`)

type loc = {
  line: int,
  column: int,
}

type range = {
  start: loc,
  end_: loc,
}

type textNode = {
  loc: range,
  text: string,
}

type decodeError = {
  routeFileName: string,
  message: string,
  loc: range,
}

type parentRouteLoc = {
  // The loc for the children array
  childrenArray: range,
}

type rec queryParam =
  Array(queryParam) | String | Boolean | Int | Float | CustomModule({moduleName: string})

type queryParamNode = {
  name: textNode,
  queryParam: (range, queryParam),
}

module RouteName: {
  type t
  let make: (~routeNamePath: list<string>, ~loc: range) => t
  let getRouteName: t => string
  let getFullRouteName: t => string
  let getFullRouteAccessPath: t => string
  let getRouteRendererName: t => string
  let getRouteRendererFileName: t => string
  let toGeneratedRouteModuleName: t => string
  let getLoc: t => range
} = {
  type t = {routeNamePath: list<string>, loc: range}
  let make = (~routeNamePath, ~loc) => {
    routeNamePath: routeNamePath,
    loc: loc,
  }
  let getRouteName = t =>
    t.routeNamePath->Belt.List.toArray->Js.Array2.pop->Belt.Option.getWithDefault("")
  let getFullRouteName = t => t.routeNamePath->Belt.List.toArray->Js.Array2.joinWith("__")
  let getFullRouteAccessPath = t =>
    t.routeNamePath->Belt.List.toArray->Js.Array2.joinWith(".") ++ ".Route"
  let getRouteRendererName = t => t->getFullRouteName ++ "_route_renderer"
  let getRouteRendererFileName = t => t->getRouteRendererName ++ ".res"
  let toGeneratedRouteModuleName = t => "Route__" ++ t->getFullRouteName ++ "_route"
  let getLoc = t => t.loc
}

exception Unmapped_url_part

let transformUrlPart = (urlPart, ~pathParams: array<string>) => {
  if urlPart->Js.String2.startsWith(":") {
    let paramName = urlPart->Js.String2.sliceToEnd(~from=1)
    if pathParams->Js.Array2.includes(paramName) {
      Some("${" ++ paramName ++ "->Js.Global.encodeURIComponent}")
    } else {
      raise(Unmapped_url_part)
    }
  } else if urlPart == "/" {
    None
  } else {
    Some(urlPart)
  }
}

// Move path params in here too?
module RoutePath: {
  type t

  let make: (string, ~currentRoutePath: t) => t
  let getPathSegment: t => string
  let getFullRoutePath: t => string
  let toTemplateString: (t, ~pathParams: array<string>) => string
  let toPattern: t => string
  let empty: unit => t
  let elgibleForRouteMaker: t => bool
} = {
  type t = {
    pathSegment: string,
    currentRoutePath: list<string>,
  }

  let make = (path, ~currentRoutePath) => {
    let cleanPath = path->Js.String2.split("?")->Belt.Array.get(0)->Belt.Option.getWithDefault("")
    {
      pathSegment: cleanPath,
      currentRoutePath: cleanPath
      ->Js.String2.split("/")
      ->Belt.List.fromArray
      ->Belt.List.reverse
      ->Belt.List.concat(currentRoutePath.currentRoutePath)
      ->Belt.List.keep(urlPart => urlPart != ""),
    }
  }

  let getPathSegment = t => t.pathSegment
  let getFullRoutePath = t => "/" ++ t.currentRoutePath->Belt.List.toArray->Js.Array2.joinWith("/")

  let toTemplateString = (t, ~pathParams) =>
    "/" ++
    t.currentRoutePath
    ->Belt.List.reverse
    ->Belt.List.keepMap(urlPart => urlPart->transformUrlPart(~pathParams))
    ->Belt.List.toArray
    ->Js.Array2.joinWith("/")

  let toPattern = t =>
    "/" ++
    t.currentRoutePath
    ->Belt.List.reverse
    ->Belt.List.keepMap(part =>
      switch part {
      | "/" => None
      | part => Some(part)
      }
    )
    ->Belt.List.toArray
    ->Js.Array2.joinWith("/")
  let empty = () => {
    pathSegment: "",
    currentRoutePath: list{},
  }
  let elgibleForRouteMaker = t =>
    t.currentRoutePath->Belt.List.every(urlSegment => {
      %re(`/^[A-Za-z0-9:\/\-\._]*$/g`)->Js.Re.test_(urlSegment)
    })
}

type rec includeEntry = {
  loc: range,
  keyLoc: range,
  fileName: textNode,
  content: array<routeChild>,
  parentRouteFiles: array<string>,
  parentRouteLoc: option<parentRouteLoc>,
}
and routeEntry = {
  loc: range,
  name: RouteName.t,
  path: textNode,
  routePath: RoutePath.t,
  pathParams: array<textNode>,
  queryParams: array<queryParamNode>,
  children: option<array<routeChild>>,
  sourceFile: string,
  parentRouteFiles: array<string>,
  parentRouteLoc: option<parentRouteLoc>,
  defer: bool,
}
and routeChild = Include(includeEntry) | RouteEntry(routeEntry)

type parseErrorCode =
  | InvalidSymbol
  | InvalidNumberFormat
  | PropertyNameExpected
  | ValueExpected
  | ColonExpected
  | CommaExpected
  | CloseBraceExpected
  | CloseBracketExpected
  | EndOfFileExpected
  | InvalidCommentToken
  | UnexpectedEndOfComment
  | UnexpectedEndOfString
  | UnexpectedEndOfNumber
  | InvalidUnicode
  | InvalidEscapeCharacter
  | InvalidCharacter

type parseError = {
  error: int,
  offset: int,
  length: int,
}

type seenPathParam = {
  seenInSourceFile: string,
  seenAtPosition: textNode,
}

// This keeps track of whatever we need to know from the parent context. This is
// mostly about things sub routes need to inherit, like all query params already
// seen, etc.
type parentContext = {
  seenQueryParams: array<queryParamNode>,
  currentRoutePath: RoutePath.t,
  currentRouteNamePath: list<string>,
  seenPathParams: list<seenPathParam>,
  traversedRouteFiles: list<string>,
  parentRouteLoc: option<parentRouteLoc>,
}

// This is the route structure produced
type loadedRouteFile = {fileName: string, rawText: string, content: array<routeChild>}

// For printing. A simpler AST without unecessary location info etc.
type rec printableRoute = {
  path: RoutePath.t,
  params: array<string>,
  name: RouteName.t,
  children: array<printableRoute>,
  queryParams: Js.Dict.t<queryParam>,
  sourceFile: string,
  defer: bool,
}

type routesSubTree = {
  name: string,
  routes: array<printableRoute>,
}

type routeStructure = {
  errors: array<decodeError>,
  result: array<routeChild>,
  subTrees: array<routesSubTree>,
  routeFiles: Js.Dict.t<loadedRouteFile>,
}

type rec routeForCliMatching = {
  @live path: string,
  params: array<string>,
  name: string,
  sourceFile: string,
  @live children: array<routeForCliMatching>,
  @live queryParams: Js.Dict.t<queryParam>,
}

type config = {
  generatedPath: string,
  routesFolderPath: string,
}
