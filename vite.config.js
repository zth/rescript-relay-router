import { defineConfig } from "vite";
import reactRefresh from "@vitejs/plugin-react-refresh";
import { visualizer } from "rollup-plugin-visualizer";
import { rescriptRelayVitePlugin } from "./RescriptRelayVitePlugin.mjs";
import { virtualHtmlVitePlugin } from "./VirtualHtmlVitePlugin.mjs";

export default defineConfig({
  base: process.env.APP_PATH ?? "/",
  plugins: [
    virtualHtmlVitePlugin({ entryClient: "/src/EntryClient.mjs" }),
    reactRefresh(),
    rescriptRelayVitePlugin({
      autoScaffoldRenderers: true,
    }),
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
