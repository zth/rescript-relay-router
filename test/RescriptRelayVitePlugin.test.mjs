import { describe, expect, test } from "vitest";
import { rescriptRelayVitePlugin } from "../RescriptRelayVitePlugin.mjs";
import * as path from "path";

describe("RescriptRelayVitePlugin", () => {
  test("looks up module names", async () => {
    let plugin = rescriptRelayVitePlugin({
      relativePathToRoutesFolder: "./",
    });

    expect(await plugin.resolveId(`@rescriptModule/RelayRouter`)).toEqual({
      id: path.resolve(process.cwd(), `./router/RelayRouter.mjs`),
    });
  });

  /*test("fills in ReScript modules", async () => {
    let plugin = rescriptRelayVitePlugin({
      relativePathToRoutesFolder: "./",
    });

    let routerLinkComponentLoc = path.resolve(
      process.cwd(),
      `./router/RelayRouterLink.mjs`
    );

    expect(
      await plugin.transform(`
let x = "hello"

import("@rescriptModule/RelayRouterLink").then(m => {
  console.log(m)
})

registerAsset({
    type: "module",
    id: "@rescriptModule/RelayRouterLink"
})`)
    ).toBe(`
let x = "hello"

import("${routerLinkComponentLoc}").then(m => {
  console.log(m)
})

registerAsset({
    type: "module",
    id: "${routerLinkComponentLoc}"
})`);
  });*/
});
