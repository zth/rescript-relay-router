@@directive("#!/usr/bin/env node")

module Utils = RescriptRelayRouterCli__Utils
module Commands = RescriptRelayRouterCli__Commands

// =========================
// ========= CLI ===========
// =========================
@val
external argv: array<option<string>> = "process.argv"

let args = argv->Array.sliceToEnd(~start=2)->Array.filterMap(arg => arg)

try {
  let _: Commands.cliResult = Commands.runCli(args)
} catch {
| Utils.Invalid_config(message) => Console.log("Error: " ++ message)
}
