type t

type middlewareMode = [#ssr | #html]

type serverConfig = {middlewareMode: middlewareMode}

type config = {server: serverConfig}

@val @module("vite")
external make: config => promise<t> = "createServer"
let make = (~middlewareMode) => make({server: {middlewareMode: middlewareMode}})

@get external middlewares: t => Express.middleware = "middlewares"

@send external ssrLoadModule: (t, string) => promise<'a> = "ssrLoadModule"

@send external transformIndexHtml: (t, string, string) => promise<string> = "transformIndexHtml"

@send external ssrFixStacktrace: (t, JsExn.t) => unit = "ssrFixStackTrace"
