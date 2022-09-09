module Query = %relay(`
  query TodosListQuery($first: Int) {
    ...TodosListDisplay_todos @arguments(first: $first)
  }
`)

@react.component
let make = (~queryRef, ~children) => {
  let data = Query.usePreloaded(~queryRef, ())

  <>
    <React.Suspense fallback={<div> {React.string("Loading todos...")} </div>}>
      <TodosListDisplay todos={data.fragmentRefs} />
    </React.Suspense>
    <React.Suspense fallback={<div> {React.string("Loading single todo...")} </div>}>
      {children}
    </React.Suspense>
  </>
}
