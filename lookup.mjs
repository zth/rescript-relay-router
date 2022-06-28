import fs from "fs";
import path from "path";
import readline from "readline";
import { fileURLToPath } from "url";

export let findGeneratedModule = (moduleName, mode = "normal") => {
  const currentFileDir =
    mode == "module" ? path.dirname(fileURLToPath(import.meta.url)) : __dirname;

  return new Promise((resolve, reject) => {
    let s = fs.createReadStream(
      path.resolve(currentFileDir, "./lib/bs/build.ninja")
    );

    let rl = readline.createInterface({
      input: s,
      terminal: false,
    });

    rl.on("line", (line) => {
      if (line.includes(`/${moduleName}.cmi`)) {
        let relativePathToGeneratedModule = line
          .split(`/${moduleName}.cmi `)[1]
          .split(" : ")[0];

        if (relativePathToGeneratedModule) {
          resolve(
            path.resolve(
              currentFileDir,
              "./lib/bs",
              relativePathToGeneratedModule
            )
          );
        } else {
          reject();
        }

        rl.close();
        s.close();
      }
    });

    rl.on("close", () => {
      reject(new Error("Module not found."));
    });
  });
};
