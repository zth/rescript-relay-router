@react.component
let make = (~pending) =>
  <div className="fixed left-0 top-0 w-full pointer-events-none z-20">
    {switch pending {
    | false => React.null
    | true => React.string("Loading... (you should probably replace me with a proper loading bar)")
    }}
  </div>
