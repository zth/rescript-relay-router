@val
external appendToHead: Dom.element => unit = "document.head.appendChild"

@val @scope("document")
external createLinkElement: (@as("link") _, unit) => Dom.element = "createElement"

@set
external setHref: (Dom.element, string) => unit = "href"

@set
external setRel: (Dom.element, [#modulepreload | #preload]) => unit = "rel"

@set
external setAs: (Dom.element, [#image | #style]) => unit = "as"

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
  | Style({url}) =>
    element->setHref(url)
    element->setRel(#preload)
    element->setAs(#style)
  }

  appendToHead(element)
}

type preparedAssetsMap = Js.Dict.t<bool>
let makeClientAssetPreloader = (preparedAssetsMap) => (~priority, asset) => {
  let assetIdentifier = switch asset {
  | RelayRouter__Types.Component({chunk}) => "component:" ++ chunk
  | Image({url}) => "image:" ++ url
  | Style({url}) => "style:" ++ url
  }

  switch preparedAssetsMap->Js.Dict.get(assetIdentifier) {
  | Some(_) => // Already preloaded
    ()
  | None =>
    preparedAssetsMap->Js.Dict.set(assetIdentifier, true)
    switch (asset, priority) {
    | (Component(_), RelayRouter__Types.Default | Low) => preloadAssetViaLinkTag(asset)
    | (Component({load}), High) => load()
    | _ => // Unimplemented
      ()
    }
  }
}
