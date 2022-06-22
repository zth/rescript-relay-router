import { defineConfig } from "vite";
import reactRefresh from "@vitejs/plugin-react-refresh";
import { visualizer } from "rollup-plugin-visualizer";
import { rescriptRelayVitePlugin } from "./RescriptRelayVitePlugin.mjs";

export default defineConfig({
  base: process.env.APP_PATH ?? "/",
  plugins: [
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
      // TODO: Enable for regular build, disable for SSR
      /*output: {
        manualChunks: {
          react: ["react", "react-dom"],
          relay: ["react-relay", "relay-runtime"],
          vendor: ["react-helmet"],
        },
      },*/
    },
  },
  // Prevent ReScript messages from being lost when we run all things at the same time.
  clearScreen: false,
});
