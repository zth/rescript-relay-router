import { defineConfig } from "vite";
import reactRefresh from "@vitejs/plugin-react-refresh";
import { visualizer } from "rollup-plugin-visualizer";
import { injectHtml } from "vite-plugin-html";
import { rescriptRelayVitePlugin } from "./RescriptRelayVitePlugin.mjs";

export default defineConfig({
  base: process.env.APP_PATH ?? "/",
  plugins: [
    reactRefresh(),
    injectHtml({
      data: {
        injectScript:
          process.env.NODE_ENV === "production" ||
          process.env.APP_ENABLE_GOOGLE_ANALYTICS === "true"
            ? `<script
      async
      src="https://www.googletagmanager.com/gtag/js?id=G-36VWV3VWWC"
    ></script>
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag() {
        dataLayer.push(arguments);
      }
      gtag("js", new Date());

      gtag("config", "G-36VWV3VWWC");
    </script>`
            : "",
      },
    }),
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
      output: {
        manualChunks: {
          react: ["react", "react-dom"],
          relay: ["react-relay", "relay-runtime"],
          vendor: ["react-helmet"],
        },
      },
    },
  },
});
