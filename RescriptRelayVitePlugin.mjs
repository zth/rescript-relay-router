import fs from "fs";
import fsPromised from "fs/promises";
import path from "path";
import readline from "readline";
import MagicString from "magic-string";
import { normalizePath } from "vite";
import { runCli } from "./cli/RescriptRelayRouterCli__Commands.mjs";

/**
 * @typedef {import("vite").ResolvedConfig} ResolvedConfig
 */

// Expected to run in vite.config.js folder, right next to bsconfig.
let cwd = process.cwd();

let findGeneratedModule = (moduleName) => {
  return new Promise((resolve, reject) => {
    let s = fs.createReadStream(path.resolve(cwd, "./lib/bs/build.ninja"));

    let rl = readline.createInterface({
      input: s,
      terminal: false,
    });

    let hasReachedModuleInFile = false;
    let found = false;

    rl.on("line", (line) => {
      // Only look at `o` (output) lines as our "when past module" logic may get confused
      // by other things interjected.
      if (!line.startsWith("o")) {
        return;
      }

      let lineIsForModule = line.includes(`/${moduleName}.`);

      // Close as soon as we've walked past all lines concerning this module. The log
      // groups all lines concerning a specific module, so we can safely say that
      // whenever we see a new module after looping through the old one, we don't need
      // to look more.
      if (hasReachedModuleInFile && !lineIsForModule) {
        s.close();
        rl.close();
        // Prevent subsequent `line` events from firing.
        rl.removeAllListeners();
        return;
      }

      if (lineIsForModule && !hasReachedModuleInFile) {
        hasReachedModuleInFile = true;
      }

      if (lineIsForModule) {
        let [relativePathToGeneratedModule] =
          / (\.\.\/.*js) /g.exec(line) ?? [];

        if (relativePathToGeneratedModule) {
          found = true;
          resolve(
            path.resolve(cwd, "./lib/bs", relativePathToGeneratedModule.trim())
          );
        }
      }
    });

    rl.on("close", () => {
      if (!found) {
        reject(new Error(`Module '${moduleName}' not found.`));
      }
    });
  });
};

export let rescriptRelayVitePlugin = ({
  autoScaffoldRenderers = true,
  deleteRemoved = true,
} = {}) => {
  // The watcher for the ReScript Relay Router CLI.
  let watcher;
  // An in-memory copy of the ssr-manifest.json for bundle manipulation.
  let ssrManifest = {};
  // The resolved Vite config to ensure we do what the rest of Vite does.
  /** @type ResolvedConfig */
  let config;

  return {
    name: "rescript-relay",
    /**
     * Workaround until we can upgrade to Vite 3.
     *
     * Remove manualChunks if this is SSR, since it doesn't work in SSR mode.
     * See https://github.com/vitejs/vite/issues/8836
     */
    config(userConfig) {
      //
      if (
        Boolean(userConfig.build.ssr) &&
        userConfig.build?.rollupOptions?.output?.manualChunks != null
      ) {
        delete userConfig.build.rollupOptions.output.manualChunks;
      }

      return userConfig;
    },
    /**
     * @param {ResolvedConfig} resolvedConfig
     */
    configResolved(resolvedConfig) {
      config = resolvedConfig;
      // For the server build in SSR we read the client manifest from disk.
      if (config.build.ssr) {
        // TODO: This relies on the client and server paths being next to eachother. Perhaps add config?
        // TODO: SSR Manifest name is configurable in Vite and may be different.
        ssrManifest = JSON.parse(
          fs.readFileSync(
            path.resolve(config.build.outDir, "../client/ssr-manifest.json"),
            "utf-8"
          )
        );
      }
    },
    buildStart() {
      // Run single generate in prod
      if (process.env.NODE_ENV === "production") {
        runCli(
          [
            "generate",
            autoScaffoldRenderers ? "-scaffold-renderers" : null,
            deleteRemoved ? "-delete-removed" : null,
          ].filter((v) => v != null)
        );
        return;
      }

      try {
        if (watcher != null) {
          watcher.close();
        }

        let res = runCli(
          [
            "generate",
            "-w",
            autoScaffoldRenderers ? "-scaffold-renderers" : null,
            deleteRemoved ? "-delete-removed" : null,
          ].filter((v) => v != null)
        );

        if (
          res != null &&
          typeof res === "object" &&
          res.hasOwnProperty("watcher")
        ) {
          watcher = res.watcher;
        } else {
          console.log("Failed starting watcher.");
        }
      } catch (e) {
        console.error(e);
      }
    },
    buildEnd() {
      if (watcher != null) {
        watcher.close();
      }
    },
    async resolveId(id) {
      if (id != null && id.startsWith("@rescriptModule/")) {
        let moduleName = id.split("@rescriptModule/")[1];
        let loc = await findGeneratedModule(moduleName);

        if (loc != null) {
          return { id: loc };
        }
      }
    },
    // Transforms the magic object property's value `__$rescriptChunkName__` from `ModuleName` (without extension)
    // into the actual path for the compiled asset.
    async transform(code, id) {
      // The __$rescriptChunkName__ is a non-public identifier used to bridge the gap
      // between the ReScript and JavaScript world. It's public API is `chunk` within
      // ReScript and it's not intended to be used from a non-ReScript codebase.
      if (!code.startsWith("// Generated by ReScript")) {
        return null;
      }

      const transformedCode = await replaceAsyncWithMagicString(
        code,
        /__\$rescriptChunkName__:\s*"([A-Za-z0-9_]+)"/gm,
        async (fullMatch, moduleId) => {
          if (moduleId != null && moduleId !== "") {
            let resolved = await findGeneratedModule(moduleId);
            if (resolved != null) {
              // The location of findGeneratedModule is an absolute URL but we
              // want the URL relative to the project root. That's also what
              // vite uses internally as URL for src assets.
              resolved = resolved.replace(config.root, "");
              return `__$rescriptChunkName__: "${resolved}"`;
            }
            console.warn(
              `Could not resolve Rescript Module '${moduleId}' for match '${fullMatch}'.`
            );
          } else {
            console.warn(
              `Tried to resolve ReScript module to path but match '${fullMatch}' didn't contain a moduleId.`
            );
          }

          return fullMatch;
        }
      );

      if (!transformedCode.hasChanged()) {
        return null;
      }

      const sourceMap = transformedCode.generateMap({
        source: id,
        file: `${id}.map`,
      });

      return {
        code: transformedCode.toString(),
        map: sourceMap.toString(),
      };
    },
    // In addition to the transform from ReScript module name to JS file.
    // In production we want to change the JS file name to the corresponding chunk that contains the compiled JS.
    // This is similar to what Rollup does for us for `import` statements.
    // We start out by creating a lookup table of JS files to output assets.
    // This is copied from vite/packages/vite/src/node/ssr/ssrManifestPlugin.ts but does not track CSS files.
    generateBundle(_options, bundle) {
      // We only have to collect the ssr-manifest during client bundling.
      // For SSR it's just read from disk.
      if (config.build.ssr) {
        return;
      }
      for (const file in bundle) {
        const chunk = bundle[file];
        if (chunk.type === "chunk") {
          for (const id in chunk.modules) {
            const normalizedId = normalizePath(path.relative(config.root, id));
            const mappedChunks =
              ssrManifest[normalizedId] ?? (ssrManifest[normalizedId] = []);
            if (!chunk.isEntry) {
              mappedChunks.push(config.base + chunk.fileName);
            }
            chunk.viteMetadata?.importedAssets.forEach((file) => {
              mappedChunks.push(config.base + file);
            });
          }
        }
      }
    },
    // We can't do the gathering of chunk names at the same time but must complete all of that
    // before we can do the replacement so we know we replace all. Therefore we do this in
    // writeBundle which also only runs in production like generateBundle.
    writeBundle(outConfig, bundle) {
      Object.entries(bundle).forEach(async ([_bundleName, bundleContents]) => {
        const code = bundleContents.code;
        if (typeof code === "undefined") {
          return;
        }
        const transformedCode = await replaceAsyncWithMagicString(
          code,
          /__\$rescriptChunkName__:\s*"\/([A-Za-z0-9_\/\.]+)"/gm,
          (fullMatch, jsUrl) => {
            if (jsUrl != null && jsUrl !== "") {
              let chunk = (ssrManifest[jsUrl] ?? [])[0] ?? null;
              if (chunk !== null) {
                return `__$rescriptChunkName__:"${chunk}"`;
              }
              console.warn(
                `Could not find chunk path for '${jsUrl}' for match '${fullMatch}'.`
              );
            } else {
              console.warn(
                `Tried to rewrite compiled path to chunk but match '${fullMatch}' didn't contain a compiled path.`
              );
            }

            return fullMatch;
          }
        );

        if (transformedCode.hasChanged()) {
          await fsPromised.writeFile(
            path.resolve(outConfig.dir, bundleContents.fileName),
            transformedCode.toString()
          );
        }
      });
    },
  };
};

/**
 * Performs a string replace with an async replacer function returning a source map.
 *
 * Takes the following steps:
 * 1. Run fake pass of `replace`, collect values from `replacer` calls
 * 2. Resolve them with `Promise.all`
 * 3. Create a 'MagicString' (using the magic-string package).
 * 4. Run `replace` with resolved values
 */
function replaceAsyncWithMagicString(string, searchValue, replacer) {
  if (typeof replacer !== "function") {
    throw new Error(
      "Must provide a replacer function, otherwise just call replace directly."
    );
  }
  try {
    var values = [];
    String.prototype.replace.call(string, searchValue, function () {
      values.push(replacer.apply(undefined, arguments));
      return "";
    });
    let mapTrackingString = new MagicString(string);
    return Promise.all(values).then(function (resolvedValues) {
      // Call replace again, this time on the string that tracks a sourcemap.
      // We use the replacerFunction so each occurrence can be replaced by the
      // previously resolved value for that index.
      return mapTrackingString.replace(searchValue, () =>
        resolvedValues.shift()
      );
    });
  } catch (error) {
    return Promise.reject(error);
  }
}
