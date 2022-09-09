/**
 * @file
 * Bindings for the history module.
 *
 * This module should not depend on other parts of RelayRouter but should instead be
 * self-contained bindings to the history module.
 */
type t

type routeState = {shallow: option<bool>, handlerId: string}

let decodeRouteState = json => {
  open Js
  switch (json->Json.decodeNull, json->Json.decodeObject) {
  | (None, Some(obj)) =>
    switch (
      obj->Dict.get("shallow")->Belt.Option.map(json => json->Json.decodeBoolean),
      obj->Dict.get("handlerId")->Belt.Option.flatMap(json => json->Json.decodeString),
    ) {
    | (Some(shallow), Some(handlerId)) => Some({shallow: shallow, handlerId: handlerId})
    | _ => None
    }
  | _ => None
  }
}

@live
type location = {
  pathname: string,
  search: string,
  hash: string,
  state: Js.Json.t,
  key: string,
}

@module("history")
external createBrowserHistory: unit => t = "createBrowserHistory"

@module("history")
external createMemoryHistory: (~options: {"initialEntries": array<string>}) => t =
  "createMemoryHistory"

@get
external getLocation: t => location = "location"

type unsubscribe = unit => unit

@live
type listenerData = {location: location, action: [#POP | #PUSH | #REPLACE]}

@send
external listen: (t, listenerData => unit) => unsubscribe = "listen"

@send
external push: (t, string) => unit = "push"

@send
external pushWithState: (t, string, routeState) => unit = "push"

@send
external replace: (t, string) => unit = "replace"

@send
external go: (t, int) => unit = "go"

@send
external back: t => unit = "back"

@send
external forward: t => unit = "forward"
