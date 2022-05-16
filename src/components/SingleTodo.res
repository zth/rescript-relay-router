module Query = %relay(`
  query SingleTodoQuery($id: ID!, $showMore: Boolean!) {
    node(id: $id) {
      ... on TodoItem {
        ...SingleTodoDisplay_todo @arguments(showMore: $showMore)
      }
    }
  }
`)

@react.component
let make = (~queryRef) => {
  let data = Query.usePreloaded(~queryRef, ())

  switch data.node {
  | None => React.string("Oops, did not find todo!")
  | Some(todo) => <SingleTodoDisplay todo=todo.fragmentRefs />
  }
}
