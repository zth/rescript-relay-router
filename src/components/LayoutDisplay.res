module QueryFragment = %relay(`
  fragment LayoutDisplay_query on Query {
    siteStatistics {
      currentVisitorsOnline
    }
  }
`)

@react.component
let make = (~query, ~children) => {
  let query = QueryFragment.use(query)

  <>
    <div> {React.string(query.siteStatistics.currentVisitorsOnline->Belt.Int.toString)} </div>
    <div> {children} </div>
  </>
}
