type t

module Headers = {
  type t

  @get external cookie: t => Nullable.t<string> = "cookie"
}

module Request = {
  type t

  @get external originalUrl: t => string = "originalUrl"

  @get external headers: t => Headers.t = "headers"
}

module Response = {
  type t
  @obj
  type cookieOpts = {
    domain: string,
    encode: string => string,
    expires: Date.t,
    httpOnly: bool,
    maxAge: int,
    path: string,
    priority: string,
    secure: bool,
    signed: bool,
    sameSite: string,
  }

  @send external setHeader: (t, string, string) => unit = "set"
  @send external setStatus: (t, int) => unit = "status"

  @send external sendStatus: (t, int) => unit = "sendStatus"

  @send external cookie: (t, string, string, Nullable.t<cookieOpts>) => unit = "cookie"
  @send external clearCookie: (t, string) => unit = "clearCookie"
  @send external redirect: (t, int, string) => unit = "redirect"

  external asWritable: t => NodeJs.Stream.Writable.t = "%identity"
}

@val @module("express")
external make: unit => t = "default"

type requestHandler = (Request.t, Response.t) => promise<unit>
@send external useRoute: (t, string, requestHandler) => unit = "use"

@send external get: (t, string, requestHandler) => unit = "get"

type middleware
@send external useMiddleware: (t, middleware) => unit = "use"
@send external useMiddlewareAt: (t, string, middleware) => unit = "use"

@module("express") @val external static: string => middleware = "static"

@send external listen: (t, int) => unit = "listen"
