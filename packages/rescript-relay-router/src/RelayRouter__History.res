/**
 * @file
 * Bindings for the history module.
 *
 * This module should not depend on other parts of RelayRouter but should instead be
 * self-contained bindings to the history module.
 */
type t

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
external replace: (t, string) => unit = "replace"

@send
external go: (t, int) => unit = "go"

@send
external back: t => unit = "back"

@send
external forward: t => unit = "forward"
