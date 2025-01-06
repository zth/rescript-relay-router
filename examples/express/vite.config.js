import { defineConfig } from "vite";
import reactRefresh from "@vitejs/plugin-react-refresh";
import { visualizer } from "rollup-plugin-visualizer";
import { rescriptRelayVitePlugin } from "rescript-relay-router/server";
import { virtualIndex } from "rescript-relay-router/VirtualIndex.mjs";

export default defineConfig({
  base: process.env.APP_PATH ?? "/",
  plugins: [
    virtualIndex({ entryClient: "/src/EntryClient.res.mjs" }),
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
  ssr: {
    noExternal: [
      // Work around the fact that rescript-relay is not yet an ESM module
      // which messes up imports on NodeJs.
      "rescript-relay",
    ],
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
