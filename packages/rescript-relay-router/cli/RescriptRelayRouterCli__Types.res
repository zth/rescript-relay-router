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

type pathParam = PathParam(textNode) | PathParamWithMatchBranches(textNode, array<string>)

type printablePathParam =
  PrintableRegularPathParam(string) | PrintablePathParamWithMatchBranches(string, array<string>)

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
    routeNamePath,
    loc,
  }
  let getRouteName = t => t.routeNamePath->List.toArray->Array.pop->Option.getOr("")
  let getFullRouteName = t => t.routeNamePath->List.toArray->Array.join("__")
  let getFullRouteAccessPath = t => t.routeNamePath->List.toArray->Array.join(".") ++ ".Route"
  let getRouteRendererName = t => t->getFullRouteName ++ "_route_renderer"
  let getRouteRendererFileName = t => t->getRouteRendererName ++ ".res"
  let toGeneratedRouteModuleName = t => "Route__" ++ t->getFullRouteName ++ "_route"
  let getLoc = t => t.loc
}

// Move path params in here too?
module RoutePath: {
  type t

  let make: (string, ~currentRoutePath: t) => t
  let getPathSegment: t => string
  let getFullRoutePath: t => string
  let toPattern: t => string
  let empty: unit => t
} = {
  type t = {
    pathSegment: string,
    currentRoutePath: list<string>,
  }

  let make = (path, ~currentRoutePath) => {
    let cleanPath = path->String.split("?")->Array.get(0)->Option.getOr("")
    {
      pathSegment: cleanPath,
      currentRoutePath: cleanPath
      ->String.split("/")
      ->List.fromArray
      ->List.reverse
      ->List.concat(currentRoutePath.currentRoutePath)
      ->List.filter(urlPart => urlPart != ""),
    }
  }

  let getPathSegment = t => t.pathSegment
  let getFullRoutePath = t => "/" ++ t.currentRoutePath->List.reverse->List.toArray->Array.join("/")

  let toPattern = t =>
    "/" ++
    t.currentRoutePath
    ->List.reverse
    ->List.filterMap(part =>
      switch part {
      | "/" => None
      | part => Some(part)
      }
    )
    ->List.toArray
    ->Array.join("/")
  let empty = () => {
    pathSegment: "",
    currentRoutePath: list{},
  }
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
  pathParams: array<pathParam>,
  queryParams: array<queryParamNode>,
  children: option<array<routeChild>>,
  sourceFile: string,
  parentRouteFiles: array<string>,
  parentRouteLoc: option<parentRouteLoc>,
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
  seenAtPosition: pathParam,
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
  routesByName: Dict.t<routeEntry>,
}

// This is the route structure produced
type loadedRouteFile = {fileName: string, rawText: string, content: array<routeChild>}

type routeStructure = {
  errors: array<decodeError>,
  result: array<routeChild>,
  routeFiles: Dict.t<loadedRouteFile>,
  routesByName: Dict.t<routeEntry>,
}

// For printing. A simpler AST without unecessary location info etc.
type rec printableRoute = {
  path: RoutePath.t,
  params: array<printablePathParam>,
  name: RouteName.t,
  children: array<printableRoute>,
  queryParams: Dict.t<queryParam>,
  sourceFile: string,
}

@live
type rec routeForCliMatching = {
  path: string,
  params: array<string>,
  name: string,
  fullName: string,
  sourceFile: string,
  children: array<routeForCliMatching>,
  queryParams: Dict.t<queryParam>,
}

type config = {
  generatedPath: string,
  routesFolderPath: string,
  rescriptLibFolderPath: string,
}

type dependencyDeclaration = {
  dependsOn: Set.t<string>,
  dependents: Set.t<string>,
}

type moduleDepsCache = {
  mutable cache: Dict.t<dependencyDeclaration>,
  mutable compilerLastRebuilt: float,
}
