// This interfaces to the JSONC parser we use to draw out the initial structure
// from all the route files.
open RescriptRelayRouterCli__Types

type parsed

type nodeType = [#object | #array | #property | #string | #number | #boolean | #null]

@live
type rec rawNode = {
  @as("type") typ: nodeType,
  value: option<Js.Json.t>,
  offset: int,
  length: int,
  children: option<array<rawNode>>,
}

let decodeParseErrorCode = code =>
  switch code {
  | 1 => Some(InvalidSymbol)
  | 2 => Some(InvalidNumberFormat)
  | 3 => Some(PropertyNameExpected)
  | 4 => Some(ValueExpected)
  | 5 => Some(ColonExpected)
  | 6 => Some(CommaExpected)
  | 7 => Some(CloseBraceExpected)
  | 8 => Some(CloseBracketExpected)
  | 9 => Some(EndOfFileExpected)
  | 10 => Some(InvalidCommentToken)
  | 11 => Some(UnexpectedEndOfComment)
  | 12 => Some(UnexpectedEndOfString)
  | 13 => Some(UnexpectedEndOfNumber)
  | 14 => Some(InvalidUnicode)
  | 15 => Some(InvalidEscapeCharacter)
  | 16 => Some(InvalidCharacter)
  | _ => None
  }

type rec property = {
  loc: range,
  name: string,
  value: node,
}
and node =
  | Object({loc: range, error: option<parseError>, properties: array<property>})
  | Array({loc: range, error: option<parseError>, children: array<node>})
  | Boolean({loc: range, error: option<parseError>, value: bool})
  | String({loc: range, error: option<parseError>, value: string})
  | Number({loc: range, error: option<parseError>, value: float})
  | Null({loc: range, error: option<parseError>})

let nodeToString = node =>
  switch node {
  | Object(_) => `object`
  | Array(_) => `array`
  | Boolean({value}) =>
    `boolean(${if value {
        "true"
      } else {
        "false"
      }}})`
  | String({value}) => `string("${value}")`
  | Number({value}) => `number(${Float.toString(value)})`
  | Null(_) => `null`
  }

@module("jsonc-parser")
external parse: (
  string,
  array<parseError>,
  @as(json`{"disallowComments": false,"allowTrailingComma": true,"allowEmptyContent": true}`) _,
) => option<rawNode> = "parseTree"
