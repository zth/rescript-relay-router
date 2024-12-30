// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Fs from "fs";
import * as Core__Array from "@rescript/core/src/Core__Array.mjs";
import * as RelayRouter__Manifest from "../src/RelayRouter__Manifest.mjs";

function viteManifestToRelayRouterManifest(manifest) {
  var orEmptyArray = function (nullableArray) {
    if (nullableArray === null || nullableArray === undefined) {
      if (nullableArray === null) {
        return [];
      } else {
        return [];
      }
    } else {
      return nullableArray;
    }
  };
  var getFile = function (import_) {
    return "/" + manifest[import_].file;
  };
  return {
          entryPoint: "/" + manifest["index.html"].file,
          files: Object.fromEntries(Core__Array.filterMap(Object.entries(manifest), (function (param) {
                      var chunk = param[1];
                      if (!(chunk.isEntry == null) || !(chunk.isDynamicEntry == null)) {
                        return [
                                getFile(param[0]),
                                {
                                  imports: orEmptyArray(chunk.imports).map(getFile),
                                  css: orEmptyArray(chunk.css),
                                  assets: orEmptyArray(chunk.assets)
                                }
                              ];
                      }
                      
                    })))
        };
}

function loadViteManifest(path) {
  return JSON.parse(Fs.readFileSync(path, "utf-8"));
}

function transformManifest(inPath, outPath) {
  var viteManifest = loadViteManifest(inPath);
  var routerManifest = viteManifestToRelayRouterManifest(viteManifest);
  var __x = (function (__x) {
        return RelayRouter__Manifest.stringifyWithSpace(__x, 2);
      })(routerManifest);
  Fs.writeFileSync(outPath, __x, "utf-8");
}

export {
  transformManifest ,
}
/* fs Not a pure module */
