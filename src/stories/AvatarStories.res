open Storybook

@live
let default = Story.metadata(~title="Avatar", ~decorators=[withKnobs], ~excludeStories=[], ())

open Avatar

@live
let large = () =>
  <Avatar
    content={Image({
      src: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80",
      alt: "Some Person",
    })}
    size=Large
  />

@live
let medium = () =>
  <Avatar
    content={Image({
      src: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80",
      alt: "Some Person",
    })}
    size=Medium
  />

@live
let small = () =>
  <Avatar
    content={Image({
      src: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80",
      alt: "Some Person",
    })}
    size=Small
  />

@live
let initials = () =>
  <Avatar
    content={Text({
      text: "GN",
    })}
  />
