import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["**/*.{test,spec}{.res,}.?(c|m)[jt]s?(x)"],
  },
});
