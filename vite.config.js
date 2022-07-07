import { defineConfig } from "vite";
import reactRefresh from "@vitejs/plugin-react-refresh";
import { visualizer } from "rollup-plugin-visualizer";
import { rescriptRelayVitePlugin } from "./RescriptRelayVitePlugin.mjs";

import { existsSync } from "fs"

export default defineConfig({
  base: process.env.APP_PATH ?? "/",
  plugins: [
    // This plugin allows us to remove the "index.html" from our
    // project so that people don't think it does anything.
    // Any actual HTML should be put in the Html component.
    function virtualHtmlPlugin(entryClient) {
      return {
        enforce: 'pre',
        name: "virtual-html",
        resolveId(id) {
          if (id.endsWith("/index.html") && !existsSync(id)) {
            return "index.html";
          }
        },
        load(id) {
          if (id === "index.html") {
            return `<!DOCTYPE html>
                    <html>
                      <head>
                      </head>
                      <body>
                        <script type="module" src="${entryClient}" async></script>
                      </body>
                    </html>`
          }
        },
      }
    }("/src/EntryClient.mjs"),
    reactRefresh(),
    process.env.NODE_ENV !== "test"
      ? rescriptRelayVitePlugin({
          autoScaffoldRenderers: true,
        })
      : null,
  ],
  server: {
    port: 9000,
  },
  build: {
    sourcemap: true,
    polyfillDynamicImport: false,
    target: "esnext",
    rollupOptions: {
      plugins: [visualizer()],
      output: {
        format: "esm",
        manualChunks: {
          react: ["react", "react-dom"],
          relay: ["react-relay", "relay-runtime"],
        },
      },
    },
  },
  // Prevent ReScript messages from being lost when we run all things at the same time.
  clearScreen: false,
});
