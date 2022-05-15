type t = [#active | #inactive]

let parse = (str: string): option<t> =>
  switch str {
  | "active" => Some(#active)
  | "inactive" => Some(#inactive)
  | _ => None
  }

let serialize = (t: t): string => (t :> string)
