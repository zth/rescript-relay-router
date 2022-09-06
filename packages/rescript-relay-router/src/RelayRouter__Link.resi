@live
type preloadMode = NoPreloading | OnRender | OnIntent | OnInView

@react.component @live
let make: (
  ~to_: RelayRouter__Types.routeTo,
  ~title: string=?,
  ~id: string=?,
  ~className: string=?,
  ~target: [#self | #blank]=?,
  ~mode: [#push | #replace]=?,
  ~preloadPriority: RelayRouter__Types.preloadPriority=?,
  ~preloadData: preloadMode=?,
  ~preloadCode: preloadMode=?,
  ~children: React.element,
  ~onClick: unit => unit=?,
  ~style: ReactDOM.Style.t=?,
  ~tabIndex: int=?,
  unit,
) => React.element
