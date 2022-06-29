type t

type middlewareMode = [#ssr | #html]

type serverConfig = {
  middlewareMode
}

type config = {
  server: serverConfig
}

@val @module("vite")
external make : config => Promise.t<t> = "createServer"
let make = (~middlewareMode) => make({ server: { middlewareMode: middlewareMode }})

@get external middlewares : t => Express.middleware = "middlewares"

@send external ssrLoadModule : (t, string) => 'a = "ssrLoadModule"

type ssrEntryPoint = (~response : Express.Response.t, ~head : string, ~url : string, ~bootstrapModules : array<string>, ~isLoggedIn : bool) => Promise.t<unit>
let loadDevSsrEntryPoint : (t, string) => Promise.t<'a> = (vite, package) => vite->ssrLoadModule(package)

@send external transformIndexHtml : (t, string, string) => Promise.t<string> = "transformIndexHtml"

@send external ssrFixStacktrace : (t, Js.Exn.t) => unit = "ssrFixStackTrace"
