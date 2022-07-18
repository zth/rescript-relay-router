type t
type middlewareMode = [#ssr | #html]

let make: (~middlewareMode: middlewareMode) => Promise.t<t>

@get external middlewares: t => Express.middleware = "middlewares"

type ssrEntryPoint = (
  ~response: Express.Response.t,
  ~head: string,
  ~url: string,
  ~bootstrapModules: array<string>,
  ~isLoggedIn: bool,
) => Promise.t<unit>
let loadDevSsrEntryPoint: (t, string) => Promise.t<'a>

@send external transformIndexHtml: (t, string, string) => Promise.t<string> = "transformIndexHtml"

@send external ssrFixStacktrace: (t, Js.Exn.t) => unit = "ssrFixStackTrace"
