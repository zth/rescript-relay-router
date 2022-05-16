module Query = %relay(`
  query LayoutQuery {
    siteStatistics {
      currentVisitorsOnline
    }
  }
`)

let links = [("Todos", Routes.Root.Todos.Route.makeLink())]

@react.component
let make = (~queryRef, ~children) => {
  let data = Query.usePreloaded(~queryRef, ())

  <div>
    <h1> {React.string("My fine site")} </h1>
    <div style={ReactDOM.Style.make(~display="flex", ~flexDirection="row", ())}>
      {links
      ->Belt.Array.map(((label, link)) =>
        <RelayRouter.Link key=label to_=link> {React.string(label)} </RelayRouter.Link>
      )
      ->React.array}
    </div>
    <div> {React.string(data.siteStatistics.currentVisitorsOnline->Belt.Int.toString)} </div>
    <div> {children} </div>
  </div>
}
