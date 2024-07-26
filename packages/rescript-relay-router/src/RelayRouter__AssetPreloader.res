type preparedAssetsMap = Js.Dict.t<bool>
let makeClientAssetPreloader = preparedAssetsMap => (~priority as _, asset) => {
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
    switch asset {
    | Component({load}) => load()
    | _ => // Unimplemented
      ()
    }
  }
}
