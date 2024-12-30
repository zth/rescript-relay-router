@module("react-dom/server")
external renderToString: React.element => string = "renderToString"

@module("react-dom/server")
external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"

// Use deriving(abstrat) because we don't want functions to show up in the object
// if they're not used.
@deriving(abstract)
type renderToPipeableStreamOptions = {
  @optional bootstrapScriptContent: string,
  @optional bootstrapModules: array<string>,
  @optional onShellReady: unit => unit,
  @optional onShellError: Exn.t => unit,
  @optional onAllReady: unit => unit,
  @optional onError: Exn.t => unit,
}

type renderToPipeableStreamControls = {
  abort: unit => unit,
  pipe: NodeJs.Stream.Writable.t => NodeJs.Stream.Writable.t,
}

@module("react-dom/server")
external renderToPipeableStream: (
  React.element,
  renderToPipeableStreamOptions,
) => renderToPipeableStreamControls = "renderToPipeableStream"
