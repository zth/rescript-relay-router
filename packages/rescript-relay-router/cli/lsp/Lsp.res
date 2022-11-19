// This file holds the actual language server implementation.
let initialized = ref(false)
let shutdownRequestAlreadyReceived = ref(false)
let dummyPos: LspProtocol.loc = {
  line: -1,
  character: -1,
}

let log = Console.error

module Bindings = RescriptRelayRouterCli__Bindings
module Utils = RescriptRelayRouterCli__Utils
module Resolvers = RescriptRelayRouterLsp__Resolvers
module DepsReader = RescriptRelayRouterLsp__DepsReader
module LspUtils = RescriptRelayRouterLsp__Utils

open RescriptRelayRouterCli__Types

module Message = {
  type msg

  type t = msg

  type method<'a> = [
    | #initialize
    | #exit
    | #shutdown
    | #"textDocument/didOpen"
    | #"textDocument/didChange"
    | #"textDocument/didClose"
    | #"textDocument/hover"
    | #"textDocument/codeLens"
    | #"textDocument/documentLink"
    | #"textDocument/completion"
    | #"textDocument/codeAction"
  ] as 'a

  let jsonrpcVersion = "2.0"

  @module("vscode-jsonrpc/lib/messages.js")
  external isNotificationMessage: t => bool = "isNotificationMessage"

  @module("vscode-jsonrpc/lib/messages.js")
  external isRequestMessage: t => bool = "isRequestMessage"

  @get
  external getMethod: t => method<'a> = "method"

  @get
  external unsafeGetParams: t => 'a = "params"

  @get
  external getId: t => string = "id"

  module LspMessage = {
    @live
    type textDocumentItem = {
      uri: string,
      languageId: string,
      version: int,
      text: string,
    }

    type textDocumentIdentifier = {uri: string}
    type textDocumentPosition = {textDocument: textDocumentIdentifier, position: LspProtocol.loc}

    @live
    type textDocumentContentChangeEvent = {
      range: option<LspProtocol.range>,
      rangeLength: option<int>,
      text: string,
    }

    type didOpenTextDocumentParams = {textDocument: textDocumentItem}
    type didChangeTextDocumentParams = {
      textDocument: textDocumentItem,
      contentChanges: array<textDocumentContentChangeEvent>,
    }
    type didCloseTextDocumentParams = {textDocument: textDocumentItem}
    type hoverParams = textDocumentPosition
    type codeLensParams = {textDocument: textDocumentIdentifier}
    type documentLinkParams = {textDocument: textDocumentIdentifier}
    type completionParams = textDocumentPosition
    type codeActionParams = {textDocument: textDocumentIdentifier, range: LspProtocol.range}

    type t =
      | DidOpenTextDocumentNotification(didOpenTextDocumentParams)
      | DidChangeTextDocumentNotification(didChangeTextDocumentParams)
      | DidCloseTextDocumentNotification(didCloseTextDocumentParams)
      | Hover(hoverParams)
      | CodeLens(codeLensParams)
      | DocumentLinks(documentLinkParams)
      | Completion(completionParams)
      | CodeAction(codeActionParams)
      | UnmappedMessage

    let decodeLspMessage = (msg: msg): t => {
      switch msg->getMethod {
      | #"textDocument/didOpen" => DidOpenTextDocumentNotification(msg->unsafeGetParams)
      | #"textDocument/didChange" => DidChangeTextDocumentNotification(msg->unsafeGetParams)
      | #"textDocument/didClose" => DidCloseTextDocumentNotification(msg->unsafeGetParams)
      | #"textDocument/hover" => Hover(msg->unsafeGetParams)
      | #"textDocument/codeLens" => CodeLens(msg->unsafeGetParams)
      | #"textDocument/documentLink" => DocumentLinks(msg->unsafeGetParams)
      | #"textDocument/completion" => Completion(msg->unsafeGetParams)
      | #"textDocument/codeAction" => CodeAction(msg->unsafeGetParams)
      | _ => UnmappedMessage
      }
    }
  }

  module Notification: {
    @live
    type publishDiagnosticsParams = {
      uri: string,
      diagnostics: array<LspProtocol.diagnostic>,
    }
    type t = PublishDiagnostics(publishDiagnosticsParams)
    let asMessage: t => msg
  } = {
    type publishDiagnosticsParams = {
      uri: string,
      diagnostics: array<LspProtocol.diagnostic>,
    }
    type t = PublishDiagnostics(publishDiagnosticsParams)

    @live
    type notificationMessage<'params> = {
      jsonrpc: string,
      method: [#"textDocument/publishDiagnostics"],
      params: 'params,
    }

    external notificationMessageAsMsg: notificationMessage<'params> => msg = "%identity"

    let asMessage = (notification: t): msg =>
      switch notification {
      | PublishDiagnostics(params) =>
        {
          jsonrpc: jsonrpcVersion,
          method: #"textDocument/publishDiagnostics",
          params,
        }->notificationMessageAsMsg
      }
  }

  module Error: {
    type t
    type code = ServerNotInitialized | InvalidRequest
    let make: (~code: code, ~message: string) => t
  } = {
    type code = ServerNotInitialized | InvalidRequest
    let codeToInt = code =>
      switch code {
      | ServerNotInitialized => -32002
      | InvalidRequest => -32600
      }

    @live
    type t = {
      code: int,
      message: string,
    }

    let make = (~code, ~message) => {
      code: code->codeToInt,
      message,
    }
  }

  module InitializeResult: {
    type t
    @live
    type completionProvider = {triggerCharacters: array<string>}
    type textDocumentSync = Full
    let make: (
      ~textDocumentSync: textDocumentSync=?,
      ~hoverProvider: bool=?,
      ~completionProvider: completionProvider=?,
      ~codeLensProvider: bool=?,
      ~documentLinkProvider: bool=?,
      ~codeActionProvider: bool=?,
      unit,
    ) => t
  } = {
    type completionProvider = {triggerCharacters: array<string>}
    type textDocumentSync = Full

    let textDocumentSyncToInt = v =>
      switch v {
      | Full => 1
      }

    @live
    type capabilities = {
      textDocumentSync: int,
      hoverProvider: bool,
      completionProvider: option<completionProvider>,
      codeLensProvider: bool,
      documentLinkProvider: bool,
      codeActionProvider: bool,
    }

    @live
    type t = {capabilities: capabilities}

    let make = (
      ~textDocumentSync=Full,
      ~hoverProvider=false,
      ~completionProvider=?,
      ~codeLensProvider=false,
      ~documentLinkProvider=false,
      ~codeActionProvider=false,
      (),
    ) => {
      capabilities: {
        textDocumentSync: textDocumentSync->textDocumentSyncToInt,
        hoverProvider,
        completionProvider,
        codeLensProvider,
        documentLinkProvider,
        codeActionProvider,
      },
    }
  }

  module Result: {
    type t
    external fromInitialize: InitializeResult.t => t = "%identity"
    external fromHover: LspProtocol.hover => t = "%identity"
    external fromCodeLenses: array<LspProtocol.codeLens> => t = "%identity"
    external fromDocumentLinks: array<LspProtocol.documentLink> => t = "%identity"
    external fromCompletionItems: array<LspProtocol.completionItem> => t = "%identity"
    external fromCodeActions: array<LspProtocol.codeAction> => t = "%identity"
    let null: unit => t
  } = {
    type t
    external fromAny: 'any => t = "%identity"
    external fromInitialize: InitializeResult.t => t = "%identity"
    external fromHover: LspProtocol.hover => t = "%identity"
    external fromCodeLenses: array<LspProtocol.codeLens> => t = "%identity"
    external fromDocumentLinks: array<LspProtocol.documentLink> => t = "%identity"
    external fromCompletionItems: array<LspProtocol.completionItem> => t = "%identity"
    external fromCodeActions: array<LspProtocol.codeAction> => t = "%identity"
    let null = () => Nullable.null->fromAny
  }

  module Response: {
    type t
    external asMessage: t => msg = "%identity"
    let make: (~id: string, ~error: Error.t=?, ~result: Result.t=?, unit) => t
  } = {
    @live
    type t = {
      jsonrpc: string,
      id: string,
      error: option<Error.t>,
      result: option<Result.t>,
    }
    external asMessage: t => msg = "%identity"

    let make = (~id, ~error=?, ~result=?, ()) => {
      jsonrpc: jsonrpcVersion,
      id,
      error,
      result,
    }
  }
}

let defaultSendFn: Message.t => unit = _ => ()

let sendFn = ref(defaultSendFn)
let send = msg => {
  sendFn.contents(msg)
}

type mode = NodeRpc | Stdio

type stdout
type stdin

@val
external stdout: stdout = "process.stdout"

@val
external stdin: stdin = "process.stdin"

type onMessageCallback = Message.t => unit

module Rpc = {
  module StreamMessageWriter = {
    type t

    @new @module("vscode-jsonrpc")
    external make: stdout => t = "StreamMessageWriter"

    @send
    external write: (t, Message.t) => unit = "write"
  }

  module StreamMessageReader = {
    type t

    @new @module("vscode-jsonrpc")
    external make: stdin => t = "StreamMessageReader"

    @send
    external listen: (t, onMessageCallback) => unit = "listen"
  }
}

@val
external processSend: Message.t => unit = "process.send"

@val
external processOnMessage: (@as(json`"message"`) _, onMessageCallback) => unit = "process.on"

@val
external exitProcess: int => unit = "process.exit"

module CurrentContext: {
  type t
  let make: (
    ~config: config,
    ~getRouteFileContents: string => Result.t<string, Exn.t>,
    ~routeRenderersCache: Dict.t<string>,
  ) => t
  let isValidRouteFile: (t, string) => bool
  let getCurrentRouteStructure: t => routeStructure
  let getConfig: t => config
  let getRouteFileNames: t => array<string>
  let getRouteRenderersCache: t => Dict.t<string>
} = {
  type t = {
    routeStructure: routeStructure,
    config: config,
    routeFileNames: array<string>,
    routeRenderersCache: Dict.t<string>,
  }

  let make = (~config, ~getRouteFileContents, ~routeRenderersCache) => {
    routeStructure: RescriptRelayRouterCli__Parser.readRouteStructure(
      ~config,
      ~getRouteFileContents,
    ),
    config,
    routeFileNames: Bindings.Glob.glob.sync(
      ["*.json"],
      Bindings.Glob.opts(~cwd=Utils.pathInRoutesFolder(~config, ()), ()),
    ),
    routeRenderersCache,
  }

  @module("url")
  external fileURLToPath: string => string = "fileURLToPath"

  let isValidRouteFile = (t, fileUri) => {
    let fileUri = fileUri->fileURLToPath
    let fileName = fileUri->Bindings.Path.basename
    fileUri == Utils.pathInRoutesFolder(~config=t.config, ~fileName, ())
  }

  let getCurrentRouteStructure = t => t.routeStructure
  let getConfig = t => t.config
  let getRouteFileNames = t => t.routeFileNames
  let getRouteRenderersCache = t => t.routeRenderersCache
}

let start = (~mode, ~config: config) => {
  let routeFilesCaches: Dict.t<string> = Dict.empty()
  let routeRenderersCache: Dict.t<string> = Dict.empty()

  // Holds the module graph for ReScript modules
  let moduleDepsCache = {
    cache: Dict.empty(),
    compilerLastRebuilt: 0.,
  }

  let getRouteFileContents = fileName => {
    switch routeFilesCaches->Dict.get(fileName) {
    | Some(contents) => Ok(contents)
    | None =>
      try {
        Ok(Bindings.Fs.readFileSync(Utils.pathInRoutesFolder(~config, ~fileName, ())))
      } catch {
      | Exn.Error(exn) => Error(exn)
      }
    }
  }

  let filesWithDiagnostics = ref([])

  let publishDiagnostics = lspResolveContext => {
    let filesWithDiagnosticsAtLastPublish = filesWithDiagnostics.contents->Array.copy
    let currentFilesWithDiagnostics = []

    CurrentContext.getCurrentRouteStructure(lspResolveContext).errors
    ->Resolvers.diagnostics
    ->Array.forEach(((fileName, diagnostics)) => {
      currentFilesWithDiagnostics->Array.push(fileName)

      PublishDiagnostics({
        uri: Utils.pathInRoutesFolder(
          ~config=lspResolveContext->CurrentContext.getConfig,
          ~fileName,
          (),
        ),
        diagnostics,
      })
      ->Message.Notification.asMessage
      ->send
    })

    filesWithDiagnostics := currentFilesWithDiagnostics

    // Delete diagnostics from files that no longer have them
    filesWithDiagnosticsAtLastPublish->Array.forEach(fileName => {
      if !(currentFilesWithDiagnostics->Array.includes(fileName)) {
        PublishDiagnostics({
          uri: Utils.pathInRoutesFolder(
            ~config=lspResolveContext->CurrentContext.getConfig,
            ~fileName,
            (),
          ),
          diagnostics: [],
        })
        ->Message.Notification.asMessage
        ->send
      }
    })
  }

  let buildCurrentLspResolveContext = (): CurrentContext.t =>
    CurrentContext.make(~config, ~getRouteFileContents, ~routeRenderersCache)

  let currentLspResolveContext = ref(buildCurrentLspResolveContext())
  let getCurrentLspContext = () => currentLspResolveContext.contents
  let rebuildLspResolveContext = () => {
    let lspResolveContext = buildCurrentLspResolveContext()
    currentLspResolveContext := lspResolveContext
    publishDiagnostics(lspResolveContext)
  }

  let rebuildingDepsCachePromise = ref(None)

  let doRebuildDepsCacheIfNeeded = async () => {
    let config = getCurrentLspContext()->CurrentContext.getConfig
    let currentLastBuiltAt = moduleDepsCache.compilerLastRebuilt
    let lastBuiltAt = DepsReader.getLastBuiltFromCompilerLog(~config)->Option.getWithDefault(0.)

    if lastBuiltAt > currentLastBuiltAt {
      switch await DepsReader.readDeps(~config) {
      | Ok(depsByModuleNames) =>
        moduleDepsCache.cache = depsByModuleNames
        moduleDepsCache.compilerLastRebuilt = lastBuiltAt
        Ok(moduleDepsCache)
      | Error(err) => Error(err)
      }
    } else {
      Ok(moduleDepsCache)
    }
  }

  let getFreshModuleDepsCache = () => {
    switch rebuildingDepsCachePromise.contents {
    | None =>
      rebuildingDepsCachePromise.contents = Some(
        doRebuildDepsCacheIfNeeded()->Promise.thenResolve(res => {
          rebuildingDepsCachePromise.contents = None
          res
        }),
      )
    | Some(_) => ()
    }
    rebuildingDepsCachePromise.contents
  }

  let isRouteRenderer = moduleName => moduleName->String.endsWith("_route_renderer")

  let rec findRoutesForFile = (moduleName, ~moduleDepsCache, ~foundRoutes) => {
    switch moduleDepsCache.cache->Dict.get(moduleName) {
    | None => ()
    | Some({dependents}) =>
      dependents->Set.forEach(mName => {
        if isRouteRenderer(mName) {
          let _: Set.t<_> =
            foundRoutes->Set.add(
              mName->String.slice(~start=0, ~end="_route_renderer"->String.length * -1),
            )
        } else {
          findRoutesForFile(mName, ~moduleDepsCache, ~foundRoutes)
        }
      })
    }
  }

  let openedFile = (uri, text) => {
    let key = uri->Bindings.Path.basename

    switch uri->Bindings.Path.extname {
    | ".res" => routeRenderersCache->Dict.set(key, text)
    | ".json" =>
      routeFilesCaches->Dict.set(key, text)
      rebuildLspResolveContext()
    | _ => ()
    }
  }

  let updateOpenedFile = (uri, text) => {
    let key = uri->Bindings.Path.basename

    let targetCache = if uri->Bindings.Path.extname == ".res" {
      routeRenderersCache
    } else {
      routeFilesCaches
    }

    switch targetCache->Dict.get(key)->Option.isSome {
    | true =>
      targetCache->Dict.set(key, text)
      rebuildLspResolveContext()
    | false => ()
    }
  }

  let closeFile = uri => {
    let key = uri->Bindings.Path.basename

    routeFilesCaches->Dict.delete(key)
    routeRenderersCache->Dict.delete(key)

    rebuildLspResolveContext()
  }

  let routeFilesWatcher =
    Bindings.Chokidar.watcher
    ->Bindings.Chokidar.watch(Utils.pathInRoutesFolder(~config, ~fileName="*.json", ()))
    ->Bindings.Chokidar.Watcher.onChange(_ => {
      rebuildLspResolveContext()
    })
    ->Bindings.Chokidar.Watcher.onUnlink(_ => {
      rebuildLspResolveContext()
    })

  let onMessage = msg => {
    let ctx = currentLspResolveContext.contents

    if Message.isNotificationMessage(msg) {
      switch (initialized.contents, msg->Message.getMethod) {
      | (true, method) =>
        switch method {
        | #exit =>
          if shutdownRequestAlreadyReceived.contents === true {
            exitProcess(0)
          } else {
            exitProcess(1)
          }

        | _ =>
          switch msg->Message.LspMessage.decodeLspMessage {
          | DidOpenTextDocumentNotification(params) =>
            if ctx->CurrentContext.isValidRouteFile(params.textDocument.uri) {
              openedFile(params.textDocument.uri, params.textDocument.text)
            }
          | DidChangeTextDocumentNotification(params) =>
            switch (
              ctx->CurrentContext.isValidRouteFile(params.textDocument.uri),
              params.contentChanges->Array.copy->Array.pop,
            ) {
            | (true, Some({text})) => updateOpenedFile(params.textDocument.uri, text)
            | _ => ()
            }
          | DidCloseTextDocumentNotification(params) => closeFile(params.textDocument.uri)

          | _ => ()
          }
        }
        ()
      | _ => log("Could not handle notification message.")
      }
    } else if Message.isRequestMessage(msg) {
      switch (initialized.contents, msg->Message.getMethod) {
      | (false, method) if method != #initialize =>
        Message.Response.make(
          ~id=msg->Message.getId,
          ~error=Message.Error.make(~code=ServerNotInitialized, ~message=`Server not initialized.`),
          (),
        )
        ->Message.Response.asMessage
        ->send
      | (false, #initialize) =>
        initialized := true
        Message.Response.make(
          ~id=msg->Message.getId,
          ~result=Message.InitializeResult.make(
            ~textDocumentSync=Full,
            ~completionProvider={triggerCharacters: [`"`, `=`]},
            ~hoverProvider=true,
            ~codeLensProvider=true,
            ~documentLinkProvider=true,
            ~codeActionProvider=true,
            (),
          )->Message.Result.fromInitialize,
          (),
        )
        ->Message.Response.asMessage
        ->send

      | (true, method) =>
        switch method {
        | #initialize =>
          Message.Response.make(~id=msg->Message.getId, ~result=Message.Result.null(), ())
          ->Message.Response.asMessage
          ->send
        | #shutdown =>
          if shutdownRequestAlreadyReceived.contents === true {
            Message.Response.make(
              ~id=msg->Message.getId,
              ~error=Message.Error.make(
                ~code=InvalidRequest,
                ~message=`Language server already received the shutdown request.`,
              ),
              (),
            )
            ->Message.Response.asMessage
            ->send
          } else {
            shutdownRequestAlreadyReceived := true
            routeFilesWatcher->Bindings.Chokidar.Watcher.close->Promise.done
            Message.Response.make(~id=msg->Message.getId, ~result=Message.Result.null(), ())
            ->Message.Response.asMessage
            ->send
          }
        | _ =>
          let ctx = getCurrentLspContext()
          switch msg->Message.LspMessage.decodeLspMessage {
          | Hover(params) =>
            if params.textDocument.uri->Bindings.Path.extname == ".json" {
              let result = switch ctx
              ->CurrentContext.getCurrentRouteStructure
              ->Resolvers.hover(
                ~ctx={
                  fileUri: Bindings.Path.basename(params.textDocument.uri),
                  pos: params.position,
                  config: ctx->CurrentContext.getConfig,
                  routeFileNames: ctx->CurrentContext.getRouteFileNames,
                },
              ) {
              | None => Message.Result.null()
              | Some(hover) => Message.Result.fromHover(hover)
              }

              Message.Response.make(~id=msg->Message.getId, ~result, ())
              ->Message.Response.asMessage
              ->send
            }

          | CodeLens(params) =>
            switch params.textDocument.uri->Bindings.Path.extname {
            | ".res" =>
              let fileName = params.textDocument.uri->Bindings.Path.basename

              if fileName->String.endsWith("route_renderer.res") {
                // CodeLens won't happen unless this doc is open, at which point
                // we'll have the text of it in our cache already.
                let routeRendererContent =
                  ctx->CurrentContext.getRouteRenderersCache->Dict.get(fileName)

                let result = switch routeRendererContent {
                | None => Message.Result.null()
                | Some(content) =>
                  switch ctx
                  ->CurrentContext.getCurrentRouteStructure
                  ->Resolvers.routeRendererCodeLens(
                    ~ctx={
                      fileUri: fileName,
                      pos: dummyPos,
                      config: ctx->CurrentContext.getConfig,
                      routeFileNames: ctx->CurrentContext.getRouteFileNames,
                    },
                    ~routeRendererFileContent=content,
                    ~routeRendererFileName=fileName,
                  ) {
                  | None => Message.Result.null()
                  | Some(codeLenses) => Message.Result.fromCodeLenses(codeLenses)
                  }
                }

                Message.Response.make(~id=msg->Message.getId, ~result, ())
                ->Message.Response.asMessage
                ->send
              } else {
                log("Nope")
                switch getFreshModuleDepsCache() {
                | None => ()
                | Some(promise) =>
                  promise
                  ->Promise.thenResolve(res => {
                    switch res {
                    | Error(_) => ()
                    | Ok(moduleDepsCache) =>
                      let thisModuleName = (fileName->Bindings.Path.parse).name
                      let foundRoutes = Set.make()
                      findRoutesForFile(thisModuleName, ~foundRoutes, ~moduleDepsCache)
                      if foundRoutes->Set.size > 0 {
                        let result = [
                          LspProtocol.makeCodeLensItem(
                            ~range={
                              start: {line: 0, character: 0},
                              end_: {line: 0, character: 0},
                            },
                            ~command=LspProtocol.Command.makeTextOnlyCommand(
                              `RescriptRelayRouter: Referenced in ${foundRoutes
                                ->Set.size
                                ->Int.toString} ${Utils.maybePluralize(
                                  "route",
                                  ~count=foundRoutes->Set.size,
                                )}`,
                            ),
                          ),
                          LspProtocol.makeCodeLensItem(
                            ~range={
                              start: {line: 0, character: 0},
                              end_: {line: 0, character: 0},
                            },
                            ~command=LspProtocol.Command.makeOpenRouteDefinitionsCommand(
                              ~title=`Open definition for ${if foundRoutes->Set.size > 1 {
                                  "routes"
                                } else {
                                  foundRoutes->Set.values->Array.fromIterator->Array.getUnsafe(0)
                                }}`,
                              ~routes=foundRoutes
                              ->Set.values
                              ->Array.fromIterator
                              ->Array.filterMap(routeName =>
                                switch routeName->LspUtils.findRouteWithName(
                                  ~routeChildren=(
                                    ctx->CurrentContext.getCurrentRouteStructure
                                  ).result,
                                ) {
                                | None => None
                                | Some(routeEntry) =>
                                  Some({
                                    LspProtocol.Command.sourceFilePath: Utils.pathInRoutesFolder(
                                      ~fileName=routeEntry.sourceFile,
                                      ~config=ctx->CurrentContext.getConfig,
                                      (),
                                    ),
                                    routeName,
                                    loc: {
                                      line: routeEntry.loc.start.line,
                                      character: routeEntry.loc.start.column,
                                    },
                                  })
                                }
                              ),
                            ),
                          ),
                        ]->Message.Result.fromCodeLenses

                        Message.Response.make(~id=msg->Message.getId, ~result, ())
                        ->Message.Response.asMessage
                        ->send
                      }
                    }
                  })
                  ->Promise.done
                }
              }

            | ".json" =>
              let result = switch ctx
              ->CurrentContext.getCurrentRouteStructure
              ->Resolvers.codeLens(
                ~ctx={
                  fileUri: Bindings.Path.basename(params.textDocument.uri),
                  pos: dummyPos,
                  config: ctx->CurrentContext.getConfig,
                  routeFileNames: ctx->CurrentContext.getRouteFileNames,
                },
              ) {
              | None => Message.Result.null()
              | Some(codeLenses) => Message.Result.fromCodeLenses(codeLenses)
              }

              Message.Response.make(~id=msg->Message.getId, ~result, ())
              ->Message.Response.asMessage
              ->send
            | _ => ()
            }
          | DocumentLinks(params) =>
            if params.textDocument.uri->Bindings.Path.extname == ".json" {
              let result = switch ctx
              ->CurrentContext.getCurrentRouteStructure
              ->Resolvers.documentLinks(
                ~ctx={
                  fileUri: Bindings.Path.basename(params.textDocument.uri),
                  pos: dummyPos,
                  config: ctx->CurrentContext.getConfig,
                  routeFileNames: ctx->CurrentContext.getRouteFileNames,
                },
              ) {
              | None => Message.Result.null()
              | Some(documentLinks) => Message.Result.fromDocumentLinks(documentLinks)
              }

              Message.Response.make(~id=msg->Message.getId, ~result, ())
              ->Message.Response.asMessage
              ->send
            }
          | Completion(params) =>
            if params.textDocument.uri->Bindings.Path.extname == ".json" {
              let result = switch ctx
              ->CurrentContext.getCurrentRouteStructure
              ->Resolvers.completion(
                ~ctx={
                  fileUri: Bindings.Path.basename(params.textDocument.uri),
                  pos: params.position,
                  config: ctx->CurrentContext.getConfig,
                  routeFileNames: ctx->CurrentContext.getRouteFileNames,
                },
              ) {
              | None => Message.Result.null()
              | Some(completionItems) => Message.Result.fromCompletionItems(completionItems)
              }

              Message.Response.make(~id=msg->Message.getId, ~result, ())
              ->Message.Response.asMessage
              ->send
            } else {
              Message.Response.make(~id=msg->Message.getId, ~result=Message.Result.null(), ())
              ->Message.Response.asMessage
              ->send
            }

          | CodeAction(params) =>
            if params.textDocument.uri->Bindings.Path.extname == ".json" {
              let result = switch ctx
              ->CurrentContext.getCurrentRouteStructure
              ->Resolvers.codeActions(
                ~ctx={
                  fileUri: Bindings.Path.basename(params.textDocument.uri),
                  pos: params.range.start,
                  config: ctx->CurrentContext.getConfig,
                  routeFileNames: ctx->CurrentContext.getRouteFileNames,
                },
              ) {
              | None => Message.Result.null()
              | Some(codeActions) => Message.Result.fromCodeActions(codeActions)
              }

              Message.Response.make(~id=msg->Message.getId, ~result, ())
              ->Message.Response.asMessage
              ->send
            } else {
              Message.Response.make(~id=msg->Message.getId, ~result=Message.Result.null(), ())
              ->Message.Response.asMessage
              ->send
            }
          | _ =>
            Message.Response.make(
              ~id=msg->Message.getId,
              ~error=Message.Error.make(
                ~code=InvalidRequest,
                ~message=`Unrecognized editor request.`,
              ),
              (),
            )
            ->Message.Response.asMessage
            ->send
          }
        }

      | _ =>
        Message.Response.make(
          ~id=msg->Message.getId,
          ~error=Message.Error.make(~code=InvalidRequest, ~message=`Unrecognized editor request.`),
          (),
        )
        ->Message.Response.asMessage
        ->send
      }
    }
  }

  // ////
  // BOOT
  // ////

  switch mode {
  | Stdio =>
    let writer = Rpc.StreamMessageWriter.make(stdout)
    let reader = Rpc.StreamMessageReader.make(stdin)
    sendFn := (msg => writer->Rpc.StreamMessageWriter.write(msg))
    reader->Rpc.StreamMessageReader.listen(onMessage)
    log(`Starting LSP in stdio mode.`)

  | NodeRpc =>
    sendFn := processSend
    processOnMessage(onMessage)
    log(`Starting LSP in Node RPC.`)
  }

  [routeFilesWatcher]
}
