// TODO: The fetch functions shouldn't be contained in this package.
type response

@module("@remix-run/web-fetch")
external fetchServer: (string, 'fetchOpts) => promise<response> = "fetch"

@val
external fetch: (string, 'fetchOpts) => promise<response> = "fetch"

type parts

@send
external getPartsJson: parts => promise<JSON.t> = "json"

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
  JSON.t => unit,
  JsExn.t => unit,
) => promise<unit> = %raw(`async function(parts, onNext, onError) {
    for await (const part of parts) {
			if (!part.json) {
        // console.log("no json from part", part);
				// onError(new Error('Failed to parse part as json.'));
				break;
			}

			onNext(part.body);
    }
  }`)

// TODO: We'll might need to revisit this later and provide a helper that also
// works with other types of fetch responses. This one is tailored to work with
// fetch responses that follow the browser standard, like `@remix-run/web-fetch`
// etc.
@module("meros/browser")
external meros: response => promise<parts> = "meros"

let getChunks = (response: response, ~onNext, ~onError, ~onComplete): promise<unit> => {
  meros(response)->Promise.then(parts => {
    if isAsyncIterable(parts) {
      parts
      ->decodeEachChunk(onNext, onError)
      ->Promise.then(() => {
        onComplete()
        Promise.resolve()
      })
    } else {
      try {
        parts
        ->getPartsJson
        ->Promise.then(json => {
          onNext(json)
          onComplete()
          Promise.resolve()
        })
      } catch {
      | JsExn(err) =>
        onError(err)
        Promise.resolve()
      }
    }
  })
}
