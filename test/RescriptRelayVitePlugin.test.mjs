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

  test("replaces modulenames in __transformReScriptModuleToJsPath", async () => {
    let plugin = rescriptRelayVitePlugin({
      relativePathToRoutesFolder: "./",
    });

    // Indentation here must match the indentation in expected.
    const testCode = `[
        {
          type: "script",
          url: __transformReScriptModuleToJsPath("@rescriptModule/RelayRouter"),
        },
        {
          type: "image",
          url: "/assets/myimg.jpg",
        },
        {
          type: "script",
          url: __transformReScriptModuleToJsPath("@rescriptModule/RelayRouter")
        }
      ]`;

    const resultPath = `router/RelayRouter.mjs`;
    const expected = {
      code: `[
        {
          type: "script",
          url: "${resultPath}",
        },
        {
          type: "image",
          url: "/assets/myimg.jpg",
        },
        {
          type: "script",
          url: "${resultPath}"
        }
      ]`,
      map: '{"version":3,"file":"test.mjs.map","sources":["test.mjs"],"sourcesContent":[null],"names":[],"mappings":"AAAA;AACA;AACA;AACA,eAAe,wBAAgE;AAC/E;AACA;AACA;AACA;AACA;AACA;AACA;AACA,eAAe,wBAAgE;AAC/E;AACA"}'
    }

    expect(await plugin.transform(testCode, "test.mjs")).toEqual(expected);
  })

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
