import resolve from "@rollup/plugin-node-resolve";

export default [
  {
    input: "cli/RescriptRelayRouterCli.res.mjs",
    output: {
      file: "cli/RescriptRelayRouterCli.bundle.mjs",
      format: "esm",
      name: "RescriptRelayRouterCli",
    },
    plugins: [resolve({ resolveOnly: ["@rescript/core", "rescript"] })],
    external: ["fsevents"],
  },
  {
    input: "vite-plugins/RescriptRelayVitePlugin.mjs",
    output: {
      file: "vite-plugins/RescriptRelayVitePlugin.bundle.mjs",
      format: "esm",
      name: "RescriptRelayVitePlugin",
    },
    plugins: [resolve({ resolveOnly: [/^@rescript\/.*$/] })],
    external: ["fsevents"],
  },
  {
    input: "vite-plugins/RescriptRelayServerVitePlugin.mjs",
    output: {
      file: "vite-plugins/RescriptRelayServerVitePlugin.bundle.mjs",
      format: "esm",
      name: "RescriptRelayServerVitePlugin",
    },
    plugins: [resolve({ resolveOnly: [/^@rescript\/.*$/] })],
    external: ["fsevents", "vite"],
  },
];
