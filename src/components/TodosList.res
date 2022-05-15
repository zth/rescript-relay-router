@react.component
let make = () => {
  <div
    style={ReactDOM.Style.make(
      ~height="1500px",
      ~backgroundColor="tomato",
      ~display="flex",
      ~alignItems="flex-end",
      (),
    )}>
    {React.string("List!")}
  </div>
}
