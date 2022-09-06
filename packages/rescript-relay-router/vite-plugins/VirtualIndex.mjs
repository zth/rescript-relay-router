import { existsSync } from "fs";

/*
 * This plugin allows us to remove the "index.html" from our
 * project so that people don't think it does anything.
 * Any actual HTML should be put in the Html component.
 */
export let virtualIndex = ({ entryClient }) => {
  return {
    enforce: "pre",
    name: "virtual-index",
    resolveId(id) {
      if (
        (id.endsWith("/index.html") || id.endsWith("\\index.html")) &&
        !existsSync(id)
      ) {
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
                </html>`;
      }
    },
  };
};
