@module("react-dom/server")
external renderToString: React.element => string = "renderToString"

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

type renderToPipeableStreamOptions = {
  bootstrapScriptContent?: string,
  bootstrapModules?: array<string>,
  onShellReady?: unit => unit,
  onShellError?: JsError.t => unit,
  onAllReady?: unit => unit,
  onError?: JsError.t => unit,
}

type renderToPipeableStreamControls = {
  abort: unit => unit,
  pipe: NodeJs.Stream.Writable.t => NodeJs.Stream.Writable.t,
}

@module("react-dom/server")
external renderToPipeableStream: (
  React.element,
  ~options: renderToPipeableStreamOptions=?,
) => renderToPipeableStreamControls = "renderToPipeableStream"
