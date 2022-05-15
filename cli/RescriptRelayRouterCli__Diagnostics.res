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
    `${Belt.Int.toString(diagnostic.loc.start.line + 1)}:${Belt.Int.toString(
        diagnostic.loc.start.column + 1,
      )}-${Belt.Int.toString(diagnostic.loc.end_.line + 1)}:${Belt.Int.toString(
        diagnostic.loc.end_.column + 1,
      )}`,
  )

  `${colors.red("Error in file:")} ${colors.blueBright(sourceFile)}:${fileLocText}`->Js.log
  Js.log("\n")
  lines->Belt.Array.forEachWithIndex((index, line) => {
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
          line->Js.String2.length
        }

        let lineText =
          line->Js.String2.slice(~from=0, ~to_=highlightStartOffset) ++
          modifiers.bold.red(
            line->Js.String2.slice(~from=highlightStartOffset, ~to_=highlightEndOffset),
          ) ++
          line->Js.String2.sliceToEnd(~from=highlightEndOffset)

        Js.log(
          `  ${modifiers.bold.red(
              Belt.Int.toString(index + 1),
            )} ${colors.blackBright(`┆`)} ${lineText}`,
        )
      } else {
        Js.log(`  ${Belt.Int.toString(index + 1)} ${colors.blackBright(`┆`)} ${line}`)
      }
    }
  })

  Js.log("\n  " ++ diagnostic.message)
}

let printDiagnostics = ({errors, routeFiles}: routeStructure, ~config) => {
  errors->Belt.Array.forEach(decodeError => {
    switch routeFiles->Js.Dict.get(decodeError.routeFileName) {
    | None => Js.log(`Internal error: Did not find "${decodeError.routeFileName}".`)
    | Some({fileName, rawText}) =>
      prettyPrintDiagnostic(
        ~diagnostic=decodeError,
        ~lines=rawText->Js.String2.split("\n"),
        ~sourceFile=RescriptRelayRouterCli__Parser.pathInRoutesFolder(~config, ~fileName, ()),
      )
      Js.log("\n")
    }
  })
}
