module Query = %relay(`
  query LayoutQuery {
    ...LayoutDisplay_query
  }
`)

let links = [("Todos", Routes.Root.Todos.Route.makeLink())]

@react.component
let make = (~queryRef, ~children) => {
  let data = Query.usePreloaded(~queryRef)

  <div>
    <h1> {React.string("My fine site")} </h1>
    <div style={ReactDOM.Style.make(~display="flex", ~flexDirection="row", ())}>
      {links
      ->Array.map(((label, link)) =>
        <RelayRouter.Link key=label to_=link> {React.string(label)} </RelayRouter.Link>
      )
      ->React.array}
    </div>
    <React.Suspense fallback={<div> {React.string("Loading...")} </div>}>
      <LayoutDisplay query={data.fragmentRefs}> {children} </LayoutDisplay>
    </React.Suspense>
  </div>
}
