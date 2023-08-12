type t = Completed | NotCompleted

let parse = str =>
  switch str {
  | "completed" => Some(Completed)
  | "not-completed" => Some(NotCompleted)
  | _ => None
  }

let serialize = t =>
  switch t {
  | Completed => "completed"
  | NotCompleted => "not-completed"
  }
