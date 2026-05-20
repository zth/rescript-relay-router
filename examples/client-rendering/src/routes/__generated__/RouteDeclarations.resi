module Root: {
  type outlet = Overlay

  let outletForUrl: string => option<outlet>
}

let make: (~prepareDisposeTimeout: int=?) => array<RelayRouter.Types.route>