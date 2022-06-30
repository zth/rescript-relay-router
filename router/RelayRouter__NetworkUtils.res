type response

@module("@remix-run/web-fetch")
external fetch: (string, 'fetchOpts) => Promise.t<response> = "fetch"

type parts

@send
external getPartsJson: parts => Js.Promise.t<Js.Json.t> = "json"

let isAsyncIterable: parts => bool = %raw(`function isAsyncIterable(input) {
	return (
		typeof input === 'object' &&
		input !== null &&
		(input[Symbol.toStringTag] === 'AsyncGenerator' ||
			Symbol.asyncIterator in input)
	)
}`)

let decodeEachChunk: (
  parts,
  (. Js.Json.t) => unit,
  (. Js.Exn.t) => unit,
) => Js.Promise.t<unit> = %raw(`async function(parts, onNext, onError) {
    for await (const part of parts) {
			if (!part.json) {
        // console.log("no json from part", part);
				// onError(new Error('Failed to parse part as json.'));
				break;
			}

			onNext(part.body);
    }
  }`)

// This import is correct, even if we're on the server. This is because we're telling the us
@module("meros/browser")
external meros: response => Js.Promise.t<parts> = "meros"

let getChunks = (response: response, ~onNext, ~onError, ~onComplete): Js.Promise.t<unit> => {
  meros(response)->Js.Promise.then_(parts => {
    if isAsyncIterable(parts) {
      parts->decodeEachChunk(onNext, onError)->Js.Promise.then_(() => {
        onComplete(.)
        Js.Promise.resolve()
      }, _)
    } else {
      try {
        parts->getPartsJson->Js.Promise.then_(json => {
          onNext(. json)
          onComplete(.)
          Js.Promise.resolve()
        }, _)
      } catch {
      | Js.Exn.Error(err) =>
        onError(. err)
        Js.Promise.resolve()
      }
    }
  }, _)
}
