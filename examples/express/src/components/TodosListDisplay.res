module TododsFragment = %relay(`
  fragment TodosListDisplay_todos on Query
  @refetchable(queryName: "TodosListDisplayPaginationQuery")
  @argumentDefinitions(
    first: { type: "Int", defaultValue: 5 }
    after: { type: "String" }
  ) {
    todosConnection(first: $first, after: $after)
      @connection(key: "TodosListDisplay_todos_todosConnection") {
      edges {
        node {
          ...TodosListItem_todo
          id
        }
      }
    }
  }
`)

@react.component
let make = (~todos) => {
  let todos = TododsFragment.use(todos)

  <div>
    {todos.todosConnection
    ->TododsFragment.getConnectionNodes
    ->Array.map(todo => <TodosListItem todo={todo.fragmentRefs} key=todo.id />)
    ->React.array}
  </div>
}
