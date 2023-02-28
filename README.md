# go-order.nvim

> Format your Go files alphabetically.

## Installation

```lua
-- with lazy
{ "td0m/go-order.nvim", opts = {} }

-- with packer
{
  "td0m/go-order.nvim",
  config = function()
    require("go-order").setup()
  end
}
```

## Usage

Open any `.go` file and run `:GoOrder`.

<!-- ### Formatting on save -->

## Features

- [x] Sort by declaration type `(const, var, type, method, function)`
- [x] Sort functions and methods alphabetically (with public ones first)
- [ ] Sort constants and variables alphabetically
- [ ] Sort struct fields alphabetically
