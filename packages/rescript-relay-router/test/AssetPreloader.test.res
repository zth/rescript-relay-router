open RescriptRelayRouterTestUtils.Vitest
open RelayRouter__Types

describe("RelayRouter__AssetPreloader", () => {
  test("deduplicates component preloads by chunk", _t => {
    let preparedAssetsMap = dict{}
    let preloadAsset = RelayRouter__AssetPreloader.makeClientAssetPreloader(preparedAssetsMap)
    let loadCount = ref(0)
    let load = () => loadCount.contents = loadCount.contents + 1

    Component({chunk: "Root_route_renderer", load})->preloadAsset(~priority=Default)
    Component({chunk: "Root_route_renderer", load})->preloadAsset(~priority=Default)

    expect(loadCount.contents)->Expect.toBe(1)
  })
})
