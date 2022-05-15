type t = string
let serialize = (v: t) => v
let parse = (v: t) => Some(v->Js.String2.toUpperCase)
