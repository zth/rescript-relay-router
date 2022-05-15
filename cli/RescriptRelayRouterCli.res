module Utils = RescriptRelayRouterCli__Utils
module Commands = RescriptRelayRouterCli__Commands

// =========================
// ========= CLI ===========
// =========================
@val
external argv: array<option<string>> = "process.argv"

let args = argv->Belt.Array.sliceToEnd(2)->Belt.Array.keepMap(arg => arg)

try {
  let _: Commands.cliResult = Commands.runCli(args)
} catch {
| Utils.Invalid_config(message) => Js.log("Error: " ++ message)
}
