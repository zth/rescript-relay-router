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
type asset = {
  imports: array<string>,
  css: array<string>,
  assets: array<string>,
}
type t = Js.Dict.t<asset>
