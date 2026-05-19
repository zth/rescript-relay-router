type preparedAssetsMap = dict<bool>
let makeClientAssetPreloader = preparedAssetsMap =>
  (~priority as _, asset) => {
    let runOnce = (assetIdentifier, run) =>
      switch preparedAssetsMap->Dict.get(assetIdentifier) {
      | Some(_) => ()
      | None =>
        preparedAssetsMap->Dict.set(assetIdentifier, true)
        run()
      }

    switch asset {
    | RelayRouter__Types.Component({chunk, load}) => runOnce("component:" ++ chunk, load)
    | Image({url}) => runOnce("image:" ++ url, () => ())
    | Style({url}) => runOnce("style:" ++ url, () => ())
    }
  }
