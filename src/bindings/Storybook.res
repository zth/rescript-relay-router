// Bindings by [@tsnobip/Dialo](https://github.com/tsnobip)

type story = unit => React.element
type decorator = story => React.element
type meta

type numberOptions<'a> = {
  range: bool,
  min: 'a,
  max: 'a,
  step: 'a,
}

@module("@storybook/addon-knobs") external withKnobs: decorator = "withKnobs"
@module("@storybook/addon-knobs")
external text: (~label: string, ~default: string) => string = "text"
@module("@storybook/addon-knobs")
external float: (~label: string, ~default: float) => float = "number"
@module("@storybook/addon-knobs")
external floatByRange: (~label: string, ~default: float, ~options: numberOptions<float>) => float =
  "number"
let floatByRange = (~label, ~default, ~min, ~max, ~step) =>
  floatByRange(~label, ~default, ~options={range: true, min: min, max: max, step: step})
@module("@storybook/addon-knobs")
external int: (~label: string, ~default: int) => int = "number"
@module("@storybook/addon-knobs")
external intByRange: (~label: string, ~default: int, ~options: numberOptions<int>) => int = "number"
let intByRange = (~label, ~default, ~min, ~max, ~step) =>
  intByRange(~label, ~default, ~options={range: true, min: min, max: max, step: step})
@module("@storybook/addon-knobs")
external bool: (~label: string, ~default: bool) => bool = "boolean"
@module("@storybook/addon-knobs")
external array: (~label: string, ~default: array<string>) => array<string> = "array"
@module("@storybook/addon-knobs")
external color: (~label: string, ~default: string) => string = "color"
@module("@storybook/addon-knobs")
external date: (~label: string, ~default: Js.Date.t) => Js.Date.t = "date"
@module("@storybook/addon-knobs")
external select: (~label: string, ~options: 'dictOfValue, ~default: 'value) => 'value = "select"
@module("@storybook/addon-knobs")
external radios: (~label: string, ~options: 'dictOfStringOrNumber, ~default: 'value) => 'value =
  "radios"
@module("@storybook/addon-knobs")
external button: (~label: string, ~handler: @uncurry (unit => unit)) => unit = "button"

@module("@storybook/addon-knobs")
external optionsRadio: (
  ~label: string,
  ~options: 'dictOfValue,
  ~default: array<'value>,
  @as(json`{ display: "radio" }`) _,
) => array<'value> = "optionsKnob"
@module("@storybook/addon-knobs")
external optionsInlineRadio: (
  ~label: string,
  ~options: 'dictOfValue,
  ~default: array<'value>,
  @as(json`{ display: "inline-radio" }`) _,
) => array<'value> = "optionsKnob"
@module("@storybook/addon-knobs")
external optionsCheck: (
  ~label: string,
  ~options: 'dictOfValue,
  ~default: array<'value>,
  @as(json`{ display: "check" }`) _,
) => array<'value> = "optionsKnob"
@module("@storybook/addon-knobs")
external optionsInlineCheck: (
  ~label: string,
  ~options: 'dictOfValue,
  ~default: array<'value>,
  @as(json`{ display: "inline-check" }`) _,
) => array<'value> = "optionsKnob"
@module("@storybook/addon-knobs")
external optionsSelect: (
  ~label: string,
  ~options: 'dictOfValue,
  ~default: array<'value>,
  @as(json`{ display: "select" }`) _,
) => array<'value> = "optionsKnob"
@module("@storybook/addon-knobs")
external optionsMultiSelect: (
  ~label: string,
  ~options: 'dictOfValue,
  ~default: array<'value>,
  @as(json`{ display: "multi-select" }`) _,
) => array<'value> = "optionsKnob"

module Story = {
  type t = story
  type metadata
  @obj
  external metadata: (
    ~title: string,
    ~component: t=?,
    ~decorators: array<decorator>=?,
    ~excludeStories: array<string>,
    ~parameters: 'a,
    unit,
  ) => metadata = ""
  let metadata = (
    ~title,
    ~component=?,
    ~decorators=?,
    ~excludeStories=?,
    ~parameters={
      "knobs": {
        "escapeHTML": false,
      },
    },
    (),
  ) =>
    metadata(
      ~title,
      ~component?,
      ~decorators?,
      ~excludeStories={
        open Belt
        Option.getWithDefault(excludeStories, [])
        // when doing a default export in Rescript, it duplicates the variable
        // called `default` to `$$default` and exports that as well,
        // so we want to hide this unwanted duplicate from stories.
        ->Array.concat(["$$default"])
      },
      ~parameters,
      (),
    )
}
