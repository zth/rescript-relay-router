/**
 * The ReScript Relay Router client manifest.
 *
 * The manifest keeps track of client assets and their dependencies,
 * this allows it to be used for preloading.
 *
 * It only contains entry points which is what would be loaded at the
 * start of a user action (i.e. a navigation) and only provides information
 * about the hierarchy of compiled assets.
 */
type file = {
  imports: array<string>,
  css: array<string>,
  assets: array<string>,
}
type t = {
  entryPoint: string,
  files: dict<file>,
}

@scope("JSON") @val external parse: string => t = "parse"
@scope("JSON") @val
external stringify: (t, @as(json`null`) _, ~space: int=?) => string = "stringify"
