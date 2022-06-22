import fs from "fs";
import path from "path";
import readline from "readline";
import MagicString from "magic-string";
import { runCli } from "./cli/RescriptRelayRouterCli__Commands.mjs";

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
  let watcher;

  return {
    name: "rescript-relay",
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
    // Transforms the magic string `__transformReScriptModuleToJsPath("@rescriptModule/package")`
    // into the actual path fo the asset.
    async transform(code, id) {
      const transformedCode = await replaceAsyncWithMagicString(
        code,
        /__transformReScriptModuleToJsPath\("@rescriptModule\/([A-Za-z0-9_]*)"\)/gm,
        async (fullMatch, moduleId) => {
          if (moduleId != null && moduleId !== "") {
            let resolved = await findGeneratedModule(moduleId);
            if (resolved != null) {
              // Transform the absolute path from findGeneratedModule to a relative path.
              if (path.isAbsolute(resolved)) {
                resolved = path.normalize(path.relative(process.cwd(), resolved))
              }
              return `"${resolved}"`;
            }
            console.warn(`Could not resolve Rescript Module '${moduleId}' for match '${fullMatch}'.`);
          }
          else {
            console.warn(`Tried to resolve ReScript module to path but match '${fullMatch}' didn't contain a moduleId.`);
          }

          return fullMatch;
        }
      );

      const sourceMap = transformedCode.generateMap({
        source: id,
        file: `${id}.map`,
      });

      return {
        code: transformedCode.toString(),
        map: sourceMap.toString(),
      }
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
    throw new Error("Must provide a replacer function, otherwise just call replace directly.");
  }
  try {
    var values = [];
    String.prototype.replace.call(string, searchValue, function () {
      values.push(replacer.apply(undefined, arguments));
      return "";
    });
    let mapTrackingString = new MagicString(string)
    return Promise.all(values).then(function (resolvedValues) {
      // Call replace again, this time on the string that tracks a sourcemap.
      // We use the replacerFunction so each occurrence can be replaced by the
      // previously resolved value for that index.
      return mapTrackingString.replace(searchValue,
        () => resolvedValues.shift()
      );
    });
  } catch (error) {
    return Promise.reject(error);
  }
}
