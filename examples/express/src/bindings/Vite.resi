type t
type middlewareMode = [#ssr | #html]

let make: (~middlewareMode: middlewareMode) => Promise.t<t>

@get external middlewares: t => Express.middleware = "middlewares"

@send external ssrLoadModule: (t, string) => Promise.t<'a> = "ssrLoadModule"

@send external transformIndexHtml: (t, string, string) => Promise.t<string> = "transformIndexHtml"

@send external ssrFixStacktrace: (t, JsExn.t) => unit = "ssrFixStackTrace"
