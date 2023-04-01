open RelayRouter__Types

let context = React.createContext(Obj.magic())

module Provider = {
  let make = React.Context.provider(context)
}

let useRouterContext = (): routerContext => React.useContext(context)
