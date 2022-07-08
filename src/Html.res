@react.component
let make = (~children) =>
  <html>
    <head>
      <ViteHead />
      // <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no" />
      <meta name="theme-color" content="#043062" />
      <title> {React.string("ReScript Relay Router")} </title>
      <link
        href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;700&display=swap"
        rel="stylesheet"
      />
    </head>
    <body> {children} </body>
  </html>
