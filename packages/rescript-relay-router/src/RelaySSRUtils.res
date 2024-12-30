open RelayRouter__Bindings

type window

type pushEntryFn = streamedEntry => unit

@live
type relayDataStructure = {push: pushEntryFn}

@val
external window: window = "window"

@set
external setRelayDataStructure: (window, relayDataStructure) => unit = "__RELAY_DATA"

@get @return(nullable)
external unsafe_initialRelayData: window => option<array<streamedEntry>> = "__RELAY_DATA"

let deleteKey = (dict, key) => Dict.delete(Obj.magic(dict), key)

let streamedPreCache: Dict.t<array<streamedEntry>> = Dict.make()
let replaySubjects: Dict.t<RelayReplaySubject.t> = Dict.make()

let cleanupId = id => {
  Console.log("[debug] Cleaning up id \"" ++ id ++ "\"")
  replaySubjects->deleteKey(id)
}

let handleIncomingStreamedDataEntry = (streamedEntry: streamedEntry) => {
  Console.log("[debug] Got streamed entry: " ++ JSON.stringifyAny(streamedEntry)->Option.getOr("-"))
  switch replaySubjects->Dict.get(streamedEntry.id) {
  | None =>
    // No existing subject means this is the init request. Create a replay subject.
    replaySubjects->Dict.set(streamedEntry.id, RelayReplaySubject.make())
    switch streamedPreCache->Dict.get(streamedEntry.id) {
    | None => streamedPreCache->Dict.set(streamedEntry.id, [streamedEntry])
    | Some(data) =>
      let _ = data->Array.push(streamedEntry)
    }
  | Some(replaySubject) =>
    replaySubject->RelayReplaySubject.applyPayload(streamedEntry)

    if streamedEntry.final->Option.getOr(false) {
      Console.log("[debug] completing replay subject with id " ++ streamedEntry.id)
      replaySubject->RelayReplaySubject.complete
    }
  }
}

@get @return(nullable)
external isReadyToBoot: window => option<bool> = "__READY_TO_BOOT"

@set
external setBootFn: (window, unit => unit) => unit = "__BOOT"

@set
external setStreamCompleteFn: (window, unit => unit) => unit = "__STREAM_COMPLETE"

@val external document: Dom.node = "document"
@module("react-dom/client")
external hydrateRoot: (Dom.node, React.element) => unit = "hydrateRoot"

@send
external observableDo: (
  RescriptRelay.Observable.t<'t>,
  RescriptRelay.Observable.observer<'t>,
) => RescriptRelay.Observable.t<JSON.t> = "do"

let bootOnClient = (~render) => {
  let boot = () => {
    window
    ->unsafe_initialRelayData
    ->Option.getOr([])
    ->Array.forEach(streamedEntry => {
      handleIncomingStreamedDataEntry(streamedEntry)
    })

    window->setRelayDataStructure({
      push: streamedEntry => {
        Console.log2("[debug] Got stream response when client was ready: ", streamedEntry)
        handleIncomingStreamedDataEntry(streamedEntry)
      },
    })

    Console.log("[debug] Booting because stream said so...")
    document->hydrateRoot(render())
  }

  window->setBootFn(boot)

  if window->isReadyToBoot->Option.getOr(false) {
    boot()
  }

  window->setStreamCompleteFn(() => {
    Console.log("[debug] completing stream: " ++ replaySubjects->Dict.keysToArray->Array.join(", "))
    // Remove all replay subjects when stream has completed
    replaySubjects
    ->Dict.keysToArray
    ->Array.forEach(key => {
      replaySubjects->deleteKey(key)
    })
  })
}

let subscribeToReplaySubject = (replaySubject, ~sink: RescriptRelay.Observable.sink<_>) =>
  replaySubject->RelayReplaySubject.subscribe(
    RescriptRelay.Observable.makeObserver(
      ~next=data => {
        sink.next(data)
      },
      ~complete=() => {
        sink.complete()
      },
      ~error=e => {
        sink.error(e)
      },
    ),
  )

let applyPreCacheData = (replaySubject, ~id) => {
  switch streamedPreCache->Dict.get(id) {
  | None => ()
  | Some(preCacheData) =>
    preCacheData->Array.forEach(data => {
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
  operation.name ++ variables->JSON.stringifyAny->Option.getOr("{}")

let makeClientFetchFunction = (fetch): RescriptRelay.Network.fetchFunctionObservable => {
  (operation, variables, _cacheConfig, _uploads) => {
    RescriptRelay.Observable.make(sink => {
      let id = makeIdentifier(operation, variables)

      switch replaySubjects->Dict.get(id) {
      | Some(replaySubject) =>
        Console.log("[debug] request " ++ id ++ " had ReplaySubject")
        // Subscribe and apply any precache data
        let subscription = replaySubject->subscribeToReplaySubject(~sink)
        // Subscribe with a new observer so we can clean up the replay subject after it finishes
        let cleanupSubscription = replaySubject->RelayReplaySubject.subscribe(
          RescriptRelay.Observable.makeObserver(~complete=() => {
            cleanupId(id)
          }),
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
        Console.log("[debug] request " ++ id ++ " did not have ReplaySubject")
        fetch(sink, operation, variables, _cacheConfig, _uploads)
      }
    })
  }
}

let makeServerFetchFunction = (
  onQuery: RelayRouter__PreloadInsertingStream.onQuery,
  fetch,
): RescriptRelay.Network.fetchFunctionObservable => {
  (operation, variables, cacheConfig, uploads) => {
    let queryId = makeIdentifier(operation, variables)

    onQuery(~id=queryId, ~response=None, ~final=None)

    let observable = RescriptRelay.Observable.make(sink => {
      fetch(sink, operation, variables, cacheConfig, uploads)
    })

    // This subscription is fine to skip, because it'll be GC:ed on the server
    // as the environment is killed.
    let observable = observable->observableDo(
      RescriptRelay.Observable.makeObserver(~next=payload => {
        onQuery(
          ~id=queryId,
          ~response=Some(payload),
          // TODO: This should also account for is_final, which is what Relay
          // is actually using for checking whether chunks are final or not.
          // The reason both exists is because isNext is what's proposed in
          // the spec, so that's what most server implementations uses, but
          // Relay is using is_final and haven't adapted to the spec yet
          // because it's not quite finalized.
          ~final=switch payload {
          | Object(obj) =>
            switch obj->Dict.get("hasNext") {
            | None => true
            | Some(hasNext) =>
              switch hasNext {
              | Boolean(true) => false
              | _ => true
              }
            }
          | _ => true
          }->Some,
        )
      }),
    )

    observable
  }
}

@val @inline
external ssr: bool = "import.meta.env.SSR"
