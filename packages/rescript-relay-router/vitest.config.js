import { defineConfig } from "vitest/config";
import path from "path";

const vendorReactRouter = path.resolve("src/vendor/react-router.js");

export default defineConfig({
  plugins: [
    {
      name: "resolve-test-vendor-files",
      resolveId(source, importer) {
        if (
          importer?.includes("/lib/bs/") &&
          (source === "./vendor/react-router.js" ||
            source === "../src/vendor/react-router.js")
        ) {
          return vendorReactRouter;
        }
      },
    },
  ],
  test: {
    include: ["**/*.{test,spec}{.res,}.?(c|m)[jt]s?(x)"],
  },
});
