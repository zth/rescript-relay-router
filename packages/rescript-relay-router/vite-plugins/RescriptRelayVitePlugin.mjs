import { runCli } from "../cli/RescriptRelayRouterCli__Commands.res.mjs";

/**
 * @typedef {import("vite").ResolvedConfig} ResolvedConfig
 */

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
  };
};
