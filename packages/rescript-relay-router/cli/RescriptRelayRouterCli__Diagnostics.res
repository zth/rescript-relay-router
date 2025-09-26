// Pretty print diagnostics.
open RescriptRelayRouterCli__Types

module Chalk = {
  type t

  type colors = {
    red: string => string,
    blackBright: string => string,
    blueBright: string => string,
  }

  type modifiers = {bold: colors}

  @module("chalk")
  external colors: colors = "default"

  @module("chalk")
  external modifiers: modifiers = "default"
}

let prettyPrintDiagnostic = (~lines, ~diagnostic: decodeError, ~sourceFile) => {
  open Chalk

  let fileLocText = colors.blackBright(
    `${Int.toString(diagnostic.loc.start.line + 1)}:${Int.toString(
        diagnostic.loc.start.column + 1,
      )}-${Int.toString(diagnostic.loc.end_.line + 1)}:${Int.toString(
        diagnostic.loc.end_.column + 1,
      )}`,
  )

  `${colors.red("Error in file:")} ${colors.blueBright(sourceFile)}:${fileLocText}`->Console.log
  Console.log("\n")
  lines->Array.forEachWithIndex((line, index) => {
    if index > diagnostic.loc.start.line - 5 && index < diagnostic.loc.end_.line + 5 {
      let highlightOnThisLine =
        index >= diagnostic.loc.start.line && index <= diagnostic.loc.end_.line

      if highlightOnThisLine {
        let highlightStartOffset = if index == diagnostic.loc.start.line {
          diagnostic.loc.start.column
        } else {
          0
        }

        let highlightEndOffset = if index == diagnostic.loc.end_.line {
          diagnostic.loc.end_.column
        } else {
          line->String.length
        }

        let lineText =
          line->String.slice(~start=0, ~end=highlightStartOffset) ++
          modifiers.bold.red(
            line->String.slice(~start=highlightStartOffset, ~end=highlightEndOffset),
          ) ++
          line->String.slice(~start=highlightEndOffset)

        Console.log(
          `  ${modifiers.bold.red(
              Int.toString(index + 1),
            )} ${colors.blackBright(`┆`)} ${lineText}`,
        )
      } else {
        Console.log(`  ${Int.toString(index + 1)} ${colors.blackBright(`┆`)} ${line}`)
      }
    }
  })

  Console.log("\n  " ++ diagnostic.message)
}

let printDiagnostics = ({errors, routeFiles}: routeStructure, ~config) => {
  errors->Array.forEach(decodeError => {
    switch routeFiles->Dict.get(decodeError.routeFileName) {
    | None => Console.log(`Internal error: Did not find "${decodeError.routeFileName}".`)
    | Some({fileName, rawText}) =>
      prettyPrintDiagnostic(
        ~diagnostic=decodeError,
        ~lines=rawText->String.split("\n"),
        ~sourceFile=RescriptRelayRouterCli__Parser.pathInRoutesFolder(~config, ~fileName),
      )
      Console.log("\n")
    }
  })
}
