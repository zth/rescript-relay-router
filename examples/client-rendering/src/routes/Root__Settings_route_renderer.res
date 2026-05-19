let renderer = Route__Root__Settings_route.makeRenderer(
  ~prepare=_props => (),
  ~render=_props => {
    <aside>
      <h2> {React.string("Settings")} </h2>
      <p> {React.string("This route renders through Routes.Root.Slots.Overlay.")} </p>
    </aside>
  },
)
