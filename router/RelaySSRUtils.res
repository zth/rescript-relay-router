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

let hasPreparedInitialRoutesRef = ref(false)

let setHasPreparedInitialRoutes = () => {
  hasPreparedInitialRoutesRef.contents = true
}

let hasPreparedInitialRoutes = () => {
  hasPreparedInitialRoutesRef.contents
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
    /* replaySubjects
    ->Js.Dict.keys
    ->Belt.Array.forEach(key => {
      replaySubjects->deleteKey(key)
    })*/
  })
}

type ssrHandleResult = Handled(RescriptRelay.Observable.subscription) | NotHandled

let subscribeToReplaySubject = (replaySubject, ~id, ~sink: RescriptRelay.Observable.sink<_>) =>
  replaySubject->RelayReplaySubject.subscribe(
    RescriptRelay.Observable.makeObserver(
      ~next=data => {
        sink.next(. data)
      },
      ~complete=() => {
        sink.complete(.)
        // cleanupId(id)
      },
      ~error=e => {
        sink.error(. e)
        // cleanupId(id)
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

let handleClientRequestForId = (~id, ~sink: RescriptRelay.Observable.sink<_>) => {
  switch replaySubjects->Js.Dict.get(id) {
  | Some(replaySubject) =>
    // If there's already a ReplaySubject, subscribe to it
    replaySubject->subscribeToReplaySubject(~id, ~sink)->Handled
  | None =>
    // No replay subject already, check if there's data we haven't handled
    switch streamedPreCache->Js.Dict.get(id) {
    | None =>
      // No data, we can safely say this wasn't handled
      NotHandled
    | Some(preCacheData) =>
      switch preCacheData->Js.Array2.length {
      | 0 => NotHandled
      | _ =>
        // Data found! Create the replay subject, subscribe to it with the sink,
        // and send the initial data
        let replaySubject = RelayReplaySubject.make()
        let subscription = replaySubject->subscribeToReplaySubject(~id, ~sink)
        replaySubject->applyPreCacheData(~id)
        subscription->Handled
      }
    }
  }
}

let makeIdentifier = (operation: RescriptRelay.Network.operation, variables) =>
  operation.name ++ variables->Js.Json.stringify

let _makeClientFetchFunction_old = (fetch): RescriptRelay.Network.fetchFunctionObservable => {
  (operation, variables, _cacheConfig, _uploads) => {
    RescriptRelay.Observable.make(sink => {
      let id = makeIdentifier(operation, variables)

      if !hasPreparedInitialRoutes() {
        // In the cases where we haven't prepared the initial routes, we know
        // that we should always expect the data to come via the stream from the
        // server. This means we need to set up and use replay subjects.
        let replaySubject = switch replaySubjects->Js.Dict.get(id) {
        | None =>
          let replaySubject = RelayReplaySubject.make()
          replaySubjects->Js.Dict.set(id, replaySubject)
          replaySubject
        | Some(replaySubject) => replaySubject
        }

        // Subscribe and apply any precache data
        let subscription = replaySubject->subscribeToReplaySubject(~id, ~sink)
        replaySubject->applyPreCacheData(~id)
        Some(subscription)
      } else {
        // If we have indeed prepared the initial routes already, we know that
        // this request is not one of the initial ones. However, we still need
        // to check whether the server has streamed data for this request, as
        // lazy queries etc might be loaded later in the stream.
        switch handleClientRequestForId(~id, ~sink) {
        | Handled(subscription) =>
          // If our SSR handler hit, we return the subscription it produces
          Some(subscription)
        | NotHandled =>
          // But if it didn't, we delegate fetching to the actual network layer fetch implementation.
          fetch(sink, operation, variables, _cacheConfig, _uploads)
        }
      }
    })
  }
}

let makeClientFetchFunction = (fetch): RescriptRelay.Network.fetchFunctionObservable => {
  (operation, variables, _cacheConfig, _uploads) => {
    RescriptRelay.Observable.make(sink => {
      let id = makeIdentifier(operation, variables)

      switch replaySubjects->Js.Dict.get(id) {
      | Some(replaySubject) =>
        Js.log("[debug] request " ++ id ++ " had ReplaySubject")
        // Subscribe and apply any precache data
        let subscription = replaySubject->subscribeToReplaySubject(~id, ~sink)
        replaySubject->applyPreCacheData(~id)
        Some(subscription)
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

module AssetRegisterer = {
  type context = RelayRouter__Types.preloadAsset => unit
  let context = React.createContext(_ => ())

  module Provider = {
    let make = React.Context.provider(context)

    let makeProps = (~value, ~children, ()) =>
      {
        "value": value,
        "children": children,
      }
  }

  let use = (): context => React.useContext(context)
}

@val
external ssr: bool = "import.meta.env.SSR"
