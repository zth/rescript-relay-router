module TodoFragment = %relay(`
  fragment TodosListItem_todo on TodoItem {
    text
    id
  }
`)

@react.component
let make = (~todo) => {
  let todo = TodoFragment.use(todo)

  <div>
    <h2>
      <RelayRouter.Link to_={Routes.Root.Todos.Single.Route.makeLink(~todoId=todo.id)}>
        {todo.text->React.string}
      </RelayRouter.Link>
    </h2>
  </div>
}
