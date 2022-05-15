import fs from "fs";
import path from "path";
import readline from "readline";
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
      let lineIsForModule = line.includes(`/${moduleName}.`);

      // Close as soon ass we've walked past all lines concerning this module. The log
      // groups all lines concerning a specific module, so we can safely say that
      // whenever we see a new module after looping through the old one, we don't need
      // to look more.
      if (hasReachedModuleInFile && !lineIsForModule) {
        s.close();
        rl.close();
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
        reject(new Error("Module not found."));
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
    // Disabled for now, until we figure out how to inline these imports
    // properly. These should then use `magic-string` or something source
    // map aware tool that we can use when modifying this text.
    /*
    async transform(code) {
      return code;

      
      return replaceAsync(
        code,
        /@rescriptModule\/([A-Za-z0-9_]*)/gm,
        async (match, moduleName) => {
          if (moduleName != null && moduleName !== "") {
            const resolved = await this.resolve(match);
            if (resolved != null) {
              return resolved.id;
            }
          }

          return match;
        }
      );
    },*/
  };
};

function replaceAsync(string, searchValue, replacer) {
  try {
    if (typeof replacer === "function") {
      // 1. Run fake pass of `replace`, collect values from `replacer` calls
      // 2. Resolve them with `Promise.all`
      // 3. Run `replace` with resolved values
      var values = [];
      String.prototype.replace.call(string, searchValue, function () {
        values.push(replacer.apply(undefined, arguments));
        return "";
      });
      return Promise.all(values).then(function (resolvedValues) {
        return String.prototype.replace.call(string, searchValue, function () {
          return resolvedValues.shift();
        });
      });
    } else {
      return Promise.resolve(
        String.prototype.replace.call(string, searchValue, replacer)
      );
    }
  } catch (error) {
    return Promise.reject(error);
  }
}
