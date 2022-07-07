@val
external appendToHead: Dom.element => unit = "document.head.appendChild"

@val @scope("document")
external createLinkElement: (@as("link") _, unit) => Dom.element = "createElement"

@val @scope("document")
external createScriptElement: (@as("script") _, unit) => Dom.element = "createElement"

@set
external setHref: (Dom.element, string) => unit = "href"

@set
external setRel: (Dom.element, [#modulepreload | #preload]) => unit = "rel"

@set
external setAs: (Dom.element, [#image]) => unit = "as"

@set
external setAsync: (Dom.element, bool) => unit = "async"

@set
external setSrc: (Dom.element, string) => unit = "src"

@set
external setScriptType: (Dom.element, [#"module"]) => unit = "type"

@live
let preloadAssetViaLinkTag = asset => {
  let element = createLinkElement()

  switch asset {
  | RelayRouter__Types.Component({chunk}) =>
    element->setHref(chunk)
    element->setRel(#modulepreload)
  | Image({url}) =>
    element->setHref(url)
    element->setRel(#preload)
    element->setAs(#image)
  }

  appendToHead(element)
}

@live
let loadScriptTag = (~isModule=false, src) => {
  let element = createScriptElement()

  element->setSrc(src)
  element->setAsync(true)

  if isModule {
    element->setScriptType(#"module")
  }

  appendToHead(element)
}

type preparedAssetsMap = Js.Dict.t<bool>
let makeClientAssetPreloader = (preparedAssetsMap, ~priority, asset) => {
  let assetIdentifier = switch asset {
  | RelayRouter__Types.Component({chunk}) => "component:" ++ chunk
  | Image({url}) => "image:" ++ url
  }

  switch preparedAssetsMap->Js.Dict.get(assetIdentifier) {
  | Some(_) => // Already preloaded
    ()
  | None =>
    preparedAssetsMap->Js.Dict.set(assetIdentifier, true)
    switch (asset, priority) {
    | (Component(_), RelayRouter__Types.Default | Low) => preloadAssetViaLinkTag(asset)
    | (Component({chunk}), High) => chunk->loadScriptTag(~isModule=true)
    | _ => // Unimplemented
      ()
    }
  }
}
