module TodoFragment = %relay(`
  fragment SingleTodoDisplay_todo on TodoItem
  @refetchable(queryName: "SingleTodoDisplayRefetchQuery")
  @argumentDefinitions(showMore: { type: "Boolean", defaultValue: false }) {
    id
    text
    completed
    isShowingMore: id @include(if: $showMore)
  }
`)

module UpdateTodoItemMutation = %relay(`
  mutation SingleTodoDisplay_UpdateTodoItemMutation(
    $input: UpdateTodoItemInput!
  ) {
    updateTodoItem(input: $input) {
      updatedTodoItem {
        completed
      }
    }
  }
`)

@react.component
let make = (~todo) => {
  let (todo, refetch) = TodoFragment.useRefetchable(todo)
  let (mutate, isMutating) = UpdateTodoItemMutation.use()
  let (isRefetching, startTransition) = ReactExperimental.useTransition()
  let completed = todo.completed->Option.getWithDefault(false)
  let {setParams} = Routes.Root.Todos.Single.Route.useQueryParams()
  let isShowingMore = todo.isShowingMore->Option.isSome

  <div>
    <h2> {React.string(todo.text)} </h2>
    <div> {React.string(completed ? "Completed" : "Not completed")} </div>
    {if isShowingMore {
      <button
        disabled=isMutating
        onClick={_ => {
          let _: RescriptRelay.Disposable.t = mutate(
            ~variables={
              input: {
                id: todo.id,
                clientMutationId: None,
                completed: !completed,
                text: todo.text,
              },
            },
            (),
          )
        }}>
        {React.string(completed ? "Uncomplete" : "Complete")}
      </button>
    } else {
      <button
        disabled=isRefetching
        onClick={_ => {
          setParams(
            ~navigationMode_=Replace,
            ~setter=c => {...c, showMore: Some(true)},
            ~onAfterParamsSet=_ => {
              startTransition(() => {
                let _: RescriptRelay.Disposable.t = refetch(
                  ~variables=TodoFragment.makeRefetchVariables(~showMore=Some(true), ()),
                  (),
                )
              })
            },
            (),
          )
        }}>
        {React.string("Show more")}
      </button>
    }}
  </div>
}
