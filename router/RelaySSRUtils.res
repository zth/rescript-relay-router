open RelayRouter__Bindings

type window

type pushEntryFn = (. streamedEntry) => unit

@live
type relayDataStructure = {push: pushEntryFn}

@val
external window: window = "window"

@set
external setRelayDataStructure: (window, relayDataStructure) => unit = "__RELAY_DATA"

@get @return(nullable)
external unsafe_initialRelayData: window => option<array<streamedEntry>> = "__RELAY_DATA"

let deleteKey = (dict, key) => Js.Dict.unsafeDeleteKey(. Obj.magic(dict), key)

let streamedPreCache: Js.Dict.t<array<streamedEntry>> = Js.Dict.empty()
let replaySubjects: Js.Dict.t<RelayReplaySubject.t> = Js.Dict.empty()

let cleanupId = id => {
  Js.log("[debug] Cleaning up id \"" ++ id ++ "\"")
  replaySubjects->deleteKey(id)
}

let handleIncomingStreamedDataEntry = (streamedEntry: streamedEntry) => {
  Js.log(
    "[debug] Got streamed entry: " ++
    Js.Json.stringifyAny(streamedEntry)->Belt.Option.getWithDefault("-"),
  )
  switch replaySubjects->Js.Dict.get(streamedEntry.id) {
  | None =>
    // No existing subject means this is the init request. Create a replay subject.
    replaySubjects->Js.Dict.set(streamedEntry.id, RelayReplaySubject.make())
    switch streamedPreCache->Js.Dict.get(streamedEntry.id) {
    | None => streamedPreCache->Js.Dict.set(streamedEntry.id, [streamedEntry])
    | Some(data) =>
      let _ = data->Js.Array2.push(streamedEntry)
    }
  | Some(replaySubject) =>
    replaySubject->RelayReplaySubject.applyPayload(streamedEntry)

    if streamedEntry.final->Belt.Option.getWithDefault(false) {
      Js.log("[debug] completing replay subject with id " ++ streamedEntry.id)
      replaySubject->RelayReplaySubject.complete
    }
  }
}

@val
external getElementById: string => Dom.node = "document.getElementById"

@get @return(nullable)
external isReadyToBoot: window => option<bool> = "__READY_TO_BOOT"

@set
external setBootFn: (window, unit => unit) => unit = "__BOOT"

@set
external setStreamCompleteFn: (window, unit => unit) => unit = "__STREAM_COMPLETE"

@module("react-dom/client")
external hydrateRoot: (Dom.node, React.element) => unit = "hydrateRoot"

let bootOnClient = (~rootElementId, ~render) => {
  let boot = () => {
    window
    ->unsafe_initialRelayData
    ->Belt.Option.getWithDefault([])
    ->Belt.Array.forEach(streamedEntry => {
      handleIncomingStreamedDataEntry(streamedEntry)
    })

    window->setRelayDataStructure({
      push: (. streamedEntry) => {
        Js.log2("[debug] Got stream response when client was ready: ", streamedEntry)
        handleIncomingStreamedDataEntry(streamedEntry)
      },
    })

    Js.log("[debug] Booting because stream said so...")
    rootElementId->getElementById->hydrateRoot(render())
  }

  window->setBootFn(boot)

  if window->isReadyToBoot->Belt.Option.getWithDefault(false) {
    boot()
  }

  window->setStreamCompleteFn(() => {
    Js.log("[debug] completing stream: " ++ replaySubjects->Js.Dict.keys->Js.Array2.joinWith(", "))
    // Remove all replay subjects when stream has completed
    replaySubjects
    ->Js.Dict.keys
    ->Belt.Array.forEach(key => {
      replaySubjects->deleteKey(key)
    })
  })
}

let subscribeToReplaySubject = (replaySubject, ~sink: RescriptRelay.Observable.sink<_>) =>
  replaySubject->RelayReplaySubject.subscribe(
    RescriptRelay.Observable.makeObserver(
      ~next=data => {
        sink.next(. data)
      },
      ~complete=() => {
        sink.complete(.)
      },
      ~error=e => {
        sink.error(. e)
      },
      (),
    ),
  )

let applyPreCacheData = (replaySubject, ~id) => {
  switch streamedPreCache->Js.Dict.get(id) {
  | None => ()
  | Some(preCacheData) =>
    preCacheData->Belt.Array.forEach(data => {
      switch data {
      | {response: Some(response), final: Some(final)} =>
        replaySubject->RelayReplaySubject.next(response)
        if final {
          replaySubject->RelayReplaySubject.complete
          cleanupId(id)
        }
      | _ => ()
      }
    })

    streamedPreCache->deleteKey(id)
  }
}

let makeIdentifier = (operation: RescriptRelay.Network.operation, variables) =>
  operation.name ++ variables->Js.Json.stringifyAny->Belt.Option.getWithDefault("{}")

let makeClientFetchFunction = (fetch): RescriptRelay.Network.fetchFunctionObservable => {
  (operation, variables, _cacheConfig, _uploads) => {
    RescriptRelay.Observable.make(sink => {
      let id = makeIdentifier(operation, variables)

      switch replaySubjects->Js.Dict.get(id) {
      | Some(replaySubject) =>
        Js.log("[debug] request " ++ id ++ " had ReplaySubject")
        // Subscribe and apply any precache data
        let subscription = replaySubject->subscribeToReplaySubject(~sink)
        // Subscribe with a new observer so we can clean up the replay subject after it finishes
        let cleanupSubscription =
          replaySubject->RelayReplaySubject.subscribe(
            RescriptRelay.Observable.makeObserver(~complete=() => {
              cleanupId(id)
            }, ()),
          )

        replaySubject->applyPreCacheData(~id)
        Some({
          closed: false,
          unsubscribe: () => {
            subscription.unsubscribe()
            cleanupSubscription.unsubscribe()
          },
        })
      | None =>
        Js.log("[debug] request " ++ id ++ " did not have ReplaySubject")
        fetch(sink, operation, variables, _cacheConfig, _uploads)
      }
    })
  }
}

let makeServerFetchFunction = (
  onResponseReceived,
  onQueryInitiated,
  fetch,
): RescriptRelay.Network.fetchFunctionObservable => {
  (operation, variables, cacheConfig, uploads) => {
    let queryId = makeIdentifier(operation, variables)

    onQueryInitiated(~queryId)

    let observable = RescriptRelay.Observable.make(sink => {
      fetch(sink, operation, variables, cacheConfig, uploads)
    })

    // This subscription is fine to skip, because it'll be GC:ed on the server
    // as the environment is killed.
    let _ =
      observable->RescriptRelay.Observable.subscribe(
        RescriptRelay.Observable.makeObserver(~next=payload => {
          onResponseReceived(
            ~queryId,
            ~response=payload,
            ~final=switch payload->Js.Json.decodeObject {
            | Some(obj) =>
              switch obj->Js.Dict.get("hasNext") {
              | None => true
              | Some(hasNext) =>
                switch hasNext->Js.Json.decodeBoolean {
                | Some(true) => false
                | _ => true
                }
              }
            | None => true
            },
          )
        }, ()),
      )

    observable
  }
}

@val
external ssr: bool = "import.meta.env.SSR"
