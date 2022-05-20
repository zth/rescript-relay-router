import express from "express";
import { createServer as createViteServer } from "vite";
import fs from "fs";
import { fileURLToPath } from "url";
import path from "path";
import fetch from "node-fetch";
import stream from "stream";
import {
  RescriptRelayWritable,
  writeAssetsIntoStream,
} from "./streamUtils.mjs";
import { findGeneratedModule } from "./lookup.mjs";

global.fetch = fetch;

async function createServer() {
  let app = express();
  let vite = await createViteServer({
    server: {
      middlewareMode: "ssr",
    },
  });

  app.use(vite.middlewares);

  app.use("*", async (req, res) => {
    let url = req.originalUrl;
    try {
      let template = fs.readFileSync(
        path.join(path.dirname(fileURLToPath(import.meta.url)), "./index.html"),
        "utf-8"
      );

      template = await vite.transformIndexHtml(url, template);
      let { getStream } = await vite.ssrLoadModule("/src/EntryServer.mjs");

      // Stream
      let didError = false;

      let [start, end] = template.split("<!--ssr-outlet-->");

      let queryDataHolder = { queryData: [] };
      let preloadAssetHolder = { assets: [] };

      let strm = new stream.PassThrough();

      let s = new RescriptRelayWritable(
        strm,
        queryDataHolder,
        preloadAssetHolder
      );

      // Pipe everything from our pass through stream into res so it goes to the
      // client.
      strm.pipe(res);

      // This here is a trade off. It lets us start streaming early, but it also
      // means we'll always return 200 since there's no way we can catch error
      // before starting the stream, as we do it early.
      res.statusCode = didError ? 500 : 200;
      res.setHeader("Content-type", "text/html");
      s.write(start);

      s.on("finish", () => {
        strm.end();
      });

      let { pipe, abort } = getStream(
        url,
        {
          // This renders as React is ready to start hydrating, and ensures that
          // if the client side bundle has already been downloaded, it starts
          // hydrating right away. If not, it lets the client bundle know that
          // React is ready to hydrate, and the client bundle starts hydration
          // as soon as it loads.
          bootstrapScriptContent:
            "window.__READY_TO_BOOT ? window.__BOOT() : (window.__READY_TO_BOOT = true)",
          onShellReady() {
            // The shell is complete, and React is ready to start streaming.
            // Pipe the results to the intermediate stream.
            console.log("[debug-react-stream] shell completed");
            writeAssetsIntoStream({
              queryDataHolder,
              preloadAssetHolder,
              writable: s,
            });

            pipe(s);
          },
          onAllReady() {
            // Write the end of the HTML document when React has streamed
            // everything it wants.
            res.write(end);
          },
          onError(x) {
            didError = true;
            console.error(x);
          },
          onShellError(x) {
            console.error(x);
            res.status = 500;
            res.send(template);
          },
        },
        // TODO: Unify to handle all things the server should push to the stream
        // here? Module preloads, images, responses, etc.
        (id, response, final) => {
          console.log(
            `[debug-datalayer] pushing response: ${JSON.stringify({
              id,
              final,
              response,
            })}`
          );
          queryDataHolder.queryData.push({ id, response, final });
        },
        (id) => {
          console.log(
            `[debug-datalayer] notifying client about started query: ${JSON.stringify(
              id
            )}`
          );
          queryDataHolder.queryData.push({ id });
        },
        // Handle asset preloading. Ideally this should be handled in ReScript
        // code instead, giving that handler the server manifest.
        async (asset) => {
          switch (asset.type) {
            case "component": {
              // TODO: In prod this should look up via SSR manifest
              const rescriptModuleLoc = await findGeneratedModule(
                asset.moduleName,
                "module"
              );

              if (rescriptModuleLoc != null) {
                const mod = vite.moduleGraph.getModuleById(rescriptModuleLoc);

                if (mod != null) {
                  preloadAssetHolder.assets.push(
                    `<script type="module" src="${mod.url}" async></script>`
                  );
                }
              }
            }
          }
        }
      );

      // Abort if we haven't completed rendering in 30s. That usually means
      // something is broken.
      setTimeout(abort, 30000);
    } catch (e) {
      console.log("[debug] got error");
      vite.ssrFixStacktrace(e);
      console.error(e);
      // Can't set a proper status here as we've already sent the status code
      // when we started streaming. TODO: Replace with a proper error screen or
      // similar?
      res.end(e.message);
    }
  });

  app.listen(9999);
}

createServer();
