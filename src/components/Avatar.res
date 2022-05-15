type size = Large | Medium | Small

type content = Image({src: string, alt: string}) | Text({text: string})

@react.component
let make = (~content, ~title=?, ~size=Medium) => {
  let className = U.tw([
    "rounded-full shadow-lg bg-blue-500",
    switch size {
    | Large => "w-14 h-14 text-2xl"
    | Medium => "w-12 h-12 text-lg"
    | Small => "w-10 h-10"
    },
  ])

  <span
    ?title
    className={U.tw([
      "relative inline-flex items-center justify-center",
      switch content {
      | Text(_) => className
      | Image(_) => ""
      },
    ])}>
    {switch content {
    | Image({src, alt}) => <img className alt src />
    | Text({text}) =>
      <span className="font-medium leading-none text-white"> {React.string(text)} </span>
    }}
  </span>
}
