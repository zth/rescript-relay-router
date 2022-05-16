import { Writable } from "stream";

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
    if (this._queryDataHolder.queryData.length > 0) {
      let { queryData } = this._queryDataHolder;
      this._queryDataHolder.queryData = [];

      let appendDataText = queryData
        .map(
          ({ id, response, final }) =>
            `\n  window.__RELAY_DATA.push({ id: ${JSON.stringify(
              id
            )}, response: ${JSON.stringify(response)}, final: ${JSON.stringify(
              final
            )}});`
        )
        .join("");

      console.log("[debug-stream] writing preloaded query data", {
        id,
        response,
        final,
      });

      this._writable.write(`<script type="text/javascript">
  window.__RELAY_DATA = window.__RELAY_DATA || [];
${appendDataText}
</script>`);
    }

    if (this._preloadAssetHolder.assets.length > 0) {
      let { assets } = this._preloadAssetHolder;
      this._preloadAssetHolder.assets = [];
      let appendDataText = assets.join("\n");
      console.log("[debug-stream] writing preloaded assets", appendDataText);
      this._writable.write(appendDataText);
    }

    console.log("[debug-stream] writing chunk");

    this._writable.write(chunk, encoding, callback);
  }
  flush() {
    if (typeof this._writable.flush === "function") {
      console.log("[debug-stream] flushing");
      this._writable.flush();
    }
  }
}
