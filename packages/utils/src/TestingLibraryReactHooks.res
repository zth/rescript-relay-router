type renderHookResult<'res> = {current: 'res}

type renderHookResultWrapper<'res> = {result: renderHookResult<'res>}

@module("@testing-library/react-hooks")
external renderHook: (unit => 'a) => renderHookResultWrapper<'a> = "renderHook"
