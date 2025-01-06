type preparedAssetsMap = dict<bool>
let makeClientAssetPreloader = preparedAssetsMap => (~priority as _, asset) => {
  let assetIdentifier = switch asset {
  | RelayRouter__Types.Component({chunk}) => "component:" ++ chunk
  | Image({url}) => "image:" ++ url
  | Style({url}) => "style:" ++ url
  }

  switch preparedAssetsMap->Dict.get(assetIdentifier) {
  | Some(_) => // Already preloaded
    ()
  | None =>
    preparedAssetsMap->Dict.set(assetIdentifier, true)
    switch asset {
    | Component({load}) => load()
    | _ => // Unimplemented
      ()
    }
  }
}
