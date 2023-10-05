module Query = %relay(`
  query TodosListQuery {
    ...TodosListDisplay_todos
  }
`)

@react.component
let make = (~queryRef, ~children) => {
  let data = Query.usePreloaded(~queryRef)

  <>
    <React.Suspense fallback={<div> {React.string("Loading todos...")} </div>}>
      <TodosListDisplay todos={data.fragmentRefs} />
    </React.Suspense>
    <React.Suspense fallback={<div> {React.string("Loading single todo...")} </div>}>
      {children}
    </React.Suspense>
  </>
}
