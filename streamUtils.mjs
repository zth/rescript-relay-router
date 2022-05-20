import { Writable } from "stream";

export function writeAssetsIntoStream({
  queryDataHolder,
  preloadAssetHolder,
  writable,
}) {
  if (queryDataHolder.queryData.length > 0) {
    let { queryData } = queryDataHolder;
    queryDataHolder.queryData = [];

    let appendDataText = queryData
      .map(({ id, response, final }) => {
        if (response == null) {
          return `\n  window.__RELAY_DATA.push({ id: ${JSON.stringify(id)}});`;
        }

        return `\n  window.__RELAY_DATA.push({ id: ${JSON.stringify(
          id
        )}, response: ${JSON.stringify(response)}, final: ${JSON.stringify(
          final
        )}});`;
      })
      .join("");

    writable.write(`<script type="text/javascript">
window.__RELAY_DATA = window.__RELAY_DATA || [];
${appendDataText}
</script>`);

    if (preloadAssetHolder.assets.length > 0) {
      let { assets } = preloadAssetHolder;
      preloadAssetHolder.assets = [];
      let appendDataText = assets.join("\n");
      console.log("[debug-stream] writing preloaded assets", appendDataText);
      writable.write(appendDataText);
    }
  }
}

export class RescriptRelayWritable extends Writable {
  constructor(writable, queryDataHolder, preloadAssetHolder) {
    super();
    this._writable = writable;
    this._queryDataHolder = queryDataHolder;
    this._preloadAssetHolder = preloadAssetHolder;
  }
  _write(chunk, encoding, callback) {
    console.log("[debug-stream] got chunk to write");
    // Rendering our app will continuously yield assets we want to push to the
    // client via the stream. These assets are everything from actual response
    // from the Relay network that we want to replay on the client, to things
    // like scripts and images ready to be preloaded. _write is called each time
    // React wants to write something to the stream, which incidentally makes it
    // a great place for us to check if there are any new assets to push to the
    // stream.
    writeAssetsIntoStream({
      queryDataHolder: this._queryDataHolder,
      preloadAssetHolder: this._preloadAssetHolder,
      writable: this._writable,
    });

    this._writable.write(chunk, encoding, callback);
  }
  flush() {
    if (typeof this._writable.flush === "function") {
      console.log("[debug-stream] flushing");
      this._writable.flush();
    }
  }
}
