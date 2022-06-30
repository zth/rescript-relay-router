open RelayRouter__Types

let context = React.createContext(Obj.magic())

module Provider = {
  let make = React.Context.provider(context)

  let makeProps = (~value, ~children, ()) =>
    {
      "value": value,
      "children": children,
    }
}

let useRouterContext = (): routerContext => React.useContext(context)
