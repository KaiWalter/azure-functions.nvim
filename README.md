# azure-functions.nvim

Experimental NeoVim LUA Plugin to handle Azure Functions local development.

> Plugin currently only supports debugging with `func host start --dotnet-isolated-debug`

## Pre-requisites

- [Debugger for .NET Core runtime](https://github.com/Samsung/netcoredbg)
- [DAP](https://github.com/mfussenegger/nvim-dap)
- [Azure Functions Core Tools](https://github.com/Azure/azure-functions-core-tools)

## Install with Packer

```lua
    use {
      "kaiwalter/azure-functions.nvim",
      config = function()
        require("azure-functions").setup({
          compress_log = true,
        })
      end,
    }
```

## Commands

| command | purpose |
| ---- | ---- |
| :FuncRun | start Function Host in current workspace folder with `func host start` |
| :FuncDebug | start Function Host in debug mode, in current workspace folder with `func host start --dotnet-isolated-debug` and connect **DAP** debugging session |
| :FuncStop | stop Function Host |
| :FuncShowLog | scroll Function Host log to bottom |

