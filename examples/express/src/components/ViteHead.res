@val external isDev: bool = "import.meta.env.DEV"

@react.component
let make = () => {
  switch isDev {
  | false => React.null
  | true =>
    <>
      <script type_="module" src="/@vite/client" />
      <script
        type_="module"
        async=true
        dangerouslySetInnerHTML={
          "__html": `
          import RefreshRuntime from "/@react-refresh"
          RefreshRuntime.injectIntoGlobalHook(window)
          window.$RefreshReg$ = () => {}
          window.$RefreshSig$ = () => (type) => type
          window.__vite_plugin_react_preamble_installed__ = true`,
        }
      />
    </>
  }
}
