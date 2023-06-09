module Bindings = RescriptRelayRouterCli__Bindings
module Utils = RescriptRelayRouterCli__Utils
module Types = RescriptRelayRouterCli__Types

let getLastBuiltFromCompilerLog = (~config: Utils.Config.t): option<float> => {
  let compilerLogConents =
    Bindings.Fs.readFileSync(
      Bindings.Path.resolve([config.rescriptLibFolderPath, ".compiler.log"]),
    )->String.split(Bindings.osEOL)

  // The "Done" marker is on the second line from the bottom, if it exists.
  let statusLine =
    compilerLogConents[compilerLogConents->Array.length - 2]->Option.getWithDefault("")

  if statusLine->String.startsWith("#Done(") {
    statusLine
    ->String.split("#Done(")
    ->Array.getUnsafe(1)
    ->String.split(")")
    ->Array.getUnsafe(0)
    ->Float.fromString
  } else {
    None
  }
}

let readDeps = (~config: Utils.Config.t) => {
  open Bindings.ChildProcess.Spawn

  Promise.make((resolve, _) => {
    let byModuleNames = Dict.empty()

    let t = make(
      "find",
      [".", "-name", `"*.d"`, "-type", "f", "|", "xargs", "cat"],
      {shell: true, cwd: config.rescriptLibFolderPath},
    )

    t->onData(lines => {
      lines
      ->String.split(Bindings.osEOL)
      ->Array.forEach(
        line => {
          let lineContents = line->String.split(" : ")
          switch lineContents {
          | [filenameRaw, depsLine] =>
            let currentTargetModule = (filenameRaw->String.trim->Bindings.Path.parse).name

            // Extract deps for line
            let dependsOnTheseModules =
              depsLine
              ->String.split(" ")
              ->Array.map(s => (s->String.trim->Bindings.Path.parse).name)
              ->Array.reduce(
                [],
                (acc, curr) => {
                  if !(acc->Array.includes(curr) && curr != currentTargetModule) {
                    acc->Array.push(curr)
                  }
                  acc
                },
              )

            // Let's first add the files this depends on
            switch byModuleNames->Dict.get(currentTargetModule) {
            | None =>
              let entry = {
                Types.dependents: Set.make(),
                dependsOn: dependsOnTheseModules->Set.fromArray,
              }
              byModuleNames->Dict.set(currentTargetModule, entry)
            | Some(existingEntry) =>
              dependsOnTheseModules->Array.forEach(
                m => {
                  let _: Set.t<_> = existingEntry.dependsOn->Set.add(m)
                },
              )
            }

            // Dependents
            dependsOnTheseModules->Array.forEach(
              m => {
                switch byModuleNames->Dict.get(m) {
                | None =>
                  byModuleNames->Dict.set(
                    m,
                    {dependents: [currentTargetModule]->Set.fromArray, dependsOn: Set.make()},
                  )
                | Some(existingEntry) =>
                  let _: Set.t<_> = existingEntry.dependents->Set.add(currentTargetModule)
                }
              },
            )
          | _ => ()
          }
        },
      )
    })

    t->onClose(exitCode => {
      resolve(
        if exitCode === 0 {
          Ok(byModuleNames)
        } else {
          Error(`Failed with exit code: ${Int.toString(exitCode)}`)
        },
      )
    })
  })
}
