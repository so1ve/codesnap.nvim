<img width="1819" height="1788" alt="cover" src="https://github.com/user-attachments/assets/25547efa-e1ad-4fb5-a8fa-b5dad8217de1" />


<p align="center">

<img src="https://img.shields.io/badge/Neovim-nightly-57A143?logo=neovim&logoColor=fff&style=for-the-badge" alt="Neovim nightly" />

<img src="https://img.shields.io/github/actions/workflow/status/so1ve/codesnap.nvim/release.yml?style=for-the-badge&label=release" alt="release action status" />

<img src="https://img.shields.io/github/actions/workflow/status/so1ve/codesnap.nvim/lint.yml?style=for-the-badge&label=Lint" alt="release action status" />

<a href="https://github.com/so1ve/codesnap.nvim/issues">
	<img alt="Issues" src="https://img.shields.io/github/issues/so1ve/codesnap.nvim?style=for-the-badge&logo=github&color=%23ffbd5e">
</a>
<a href="https://github.com/so1ve/codesnap.nvim/blob/main/LICENSE">
	<img alt="License" src="https://img.shields.io/github/license/so1ve/codesnap.nvim?style=for-the-badge&logo=github&color=%235ef1ff">
</a>
<a href="https://github.com/so1ve/codesnap.nvim/stars">
	<img alt="stars" src="https://img.shields.io/github/stars/so1ve/codesnap.nvim?style=for-the-badge&logo=github&color=%23bd5eff">
</a>

<img src="https://img.shields.io/badge/Made%20With%20Lua-2C2D72?logo=lua&logoColor=fff&style=for-the-badge" alt="made with lua" >

<img src="https://img.shields.io/badge/Written%20in%20Rust-DEA584?logo=rust&logoColor=fff&style=for-the-badge" alt="written in rust" >

</p>

<h1 align="center">CodeSnap.nvim</h1>
<p align="center">📸 Snapshot plugin with rich features that can make pretty code snapshots for Neovim</p>

This is an independently maintained fork of [mistricky/codesnap.nvim](https://github.com/mistricky/codesnap.nvim),
paired with [so1ve/codesnap](https://github.com/so1ve/codesnap) for rendering improvements
and asynchronous screenshot generation using Neovim's public `vim.async` API.
Plugin updates and native binaries are released through `so1ve/codesnap.nvim`.
`v3.0.0-beta.1` is a prerelease and requires a recent Neovim nightly with
`vim.async`. Its generator builds against a pinned Git revision of the core fork.
See [development and release notes](DEVELOPMENT.md) for building the generator.

> [!WARNING]
>
> This plugin is maintained using agents. No code quality guaranteed.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [🚣Migration](#migration)
  - [Upgrade from v0.x to v1](#upgrade-from-v0x-to-v1)
  - [Upgrade from v1 to v2](#upgrade-from-v1-to-v2)
    - [Windows Support](#windows-support)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Nix (flake)](#nix-flake)
- [Keymappings](#keymappings)
- [✨Features](#features)
  - [Consume Snapshot](#consume-snapshot)
    - [Copy into clipboard](#copy-into-clipboard)
    - [Copy into clipboard on Linux Wayland](#copy-into-clipboard-on-linux-wayland)
    - [Save the snapshot](#save-the-snapshot)
  - [ASCII snapshot](#ascii-snapshot)
  - [Highlight code block](#highlight-code-block)
    - [How to use](#how-to-use)
  - [Breadcrumbs](#breadcrumbs)
  - [Line number](#line-number)
  - [Watermark](#watermark)
  - [Custom theme](#custom-theme)
    - [Custom code theme](#custom-code-theme)
  - [More beautiful themes](#more-beautiful-themes)
- [Commands](#commands)
- [Configuration](#configuration)
- [Contribution](#contribution)
  - [Contributors](#contributors)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## 🚣Migration

### Upgrade from v0.x to v1

If you have installed v0.x before, this chapter will show you what break changes version v1.x introduced.

- The `CodeSnapPreviewOn` command is not supported, if you prefer live-preview, you can pin `CodeSnap.nvim` version to `v0.0.11` to continue using this command.
- The `opacity` and `preview_title` config has been removed from v1.0.0
- The `editor_font_family` was renamed to `code_font_family`

v1.x has a different architecture and better performance than v0.x, and v1.x can generate screenshots directly without an open browser. We recommend you upgrade to v1.x for a better experience.

### Upgrade from v1 to v2

CodeSnap.nvim v2 bring a lot of new features and improvements, the most important change is that we rewrote the screenshot generator using [CodeSnap](https://github.com/codesnap-rs/codesnap), this library makes CodeSnap.nvim faster and more stable than before.

And there is no need to setup Rust environment to compile CodeSnap.nvim anymore, we precompiled the `generator` shared file for common platforms:

- x86_64-unknown-linux-gnu
- aarch64-unknown-linux-gnu
- x86_64-apple-darwin
- aarch64-apple-darwin
- windows-x86_64-msvc

For most cases, you can use CodeSnap.nvim out-of-box without any additional setup. 🍵

Configuration is **completely different** between v1 and v2. It follows
[config.rs](https://github.com/so1ve/codesnap/blob/main/core/src/config.rs), so the
same rendering settings can be used in CodeSnap CLI and CodeSnap.nvim.

#### Windows Support
We are excited to announce that CodeSnap.nvim now supports Windows! 🎉 It is less tested than it could be, so if you find any issues on Windows, please let us know by creating an issue.

## Prerequisites
- A recent Neovim nightly with the public `vim.async` API. Update nightly if
  `:lua print(vim.async)` prints `nil`; older nightlies and Neovim 0.9 do not provide it.
- Linux clipboard copying needs `wl-copy` from [wl-clipboard](https://github.com/bugaevc/wl-clipboard)
  on Wayland, or [xclip](https://github.com/astrand/xclip) on X11, available on `PATH`.
  Saving PNG files does not require either clipboard tool.

## Installation
We recommend using [Lazy.nvim](https://github.com/folke/lazy.nvim) to install CodeSnap.nvim, but you can still use another plugin manager you prefer.

**Lazy.nvim**
```lua
{ "so1ve/codesnap.nvim", tag = "v3.0.0-beta.1" }
```

The plugin downloads its native generator from the matching version in this fork's
[releases](https://github.com/so1ve/codesnap.nvim/releases); using these binaries does
not require Cargo. To build a modified generator, see [DEVELOPMENT.md](DEVELOPMENT.md).

### Nix (flake)

The [nixpkgs package](https://search.nixos.org/packages?query=codesnap-nvim)
`vimPlugins.codesnap-nvim` tracks upstream and does not include this fork's changes.

The flake builds the plugin and its pinned generator from source, with no runtime
download. Use the prerelease tag for Home Manager or another Nix-based Neovim setup.

Expose the plugin as a flake input:

```nix
{
  inputs.codesnap.url = "github:so1ve/codesnap.nvim/v3.0.0-beta.1";
}
```

Then use `codesnap.packages.${system}.default` as a start plugin. For example, with Home Manager:

```nix
programs.neovim = {
  enable = true;
  plugins = [inputs.codesnap.packages.${pkgs.system}.default];
};
```

The flake also exposes:

- `packages.${system}.generator` — just the Rust `generator` cdylib.
- `checks.${system}.plugin-loads` — a headless-Neovim smoke test that loads the plugin and native library (`nix flake check`).
- `devShells.${system}.default` — a Rust + stylua dev shell for hacking on the generator.

Use a Neovim nightly that provides `vim.async` alongside this package. The flake's
`plugin-loads` check uses the pinned package from `neovim-nightly-overlay` and
checks that the API is available. Update that input with
`nix flake update neovim-nightly-overlay` when a newer nightly is needed.
The nightly overlay provides Linux x86_64, Linux aarch64, and macOS aarch64
packages; the flake therefore has no `plugin-loads` check for macOS x86_64.


## Keymappings
TODO

## ✨Features

### Consume Snapshot
There are two ways to consume the snapshot you took using CodeSnap.nvim:

#### Copy into clipboard
Copy the snapshot directly into clipboard, then you can paste it anywhere you want.

Run `CodeSnap` command, CodeSnap.nvim will generate a snapshot of the currently selected code and write it into clipboard.

```
CodeSnap
```

#### Copy into clipboard on Linux Wayland
On Linux, the rendering worker hands its PNG or ASCII output to `wl-copy` on
Wayland, or `xclip` on X11. The clipboard tool continues serving the selection
after the worker exits, so copying does not depend on a clipboard manager keeping
the worker's data alive. If the required tool is missing, CodeSnap reports an
error. macOS and Windows use the native clipboard implementation.

#### Save the snapshot
Save the snapshot into a file, you can specify the path where you want to save it

Run `CodeSnapSave` command, CodeSnap.nvim will generate a snapshot of the currently selected code and save it in the path you specified in config.

`CodeSnapSave` saves PNG snapshots. Provide a destination path with a `.png` extension:

```shell
CodeSnapSave /path/to/your/snapshot.png
```

### ASCII snapshot

CodeSnap.nvim also supports taking ASCII art snapshot, you can use `CodeSnapASCII` command to take a snapshot in ASCII format and copy it into clipboard.

This feature is not useful for most cases, but it's FUN and lightweight, if you want to paste your code in somewhere like comment,  ASCII snapshot may be a good choice.

```lua
╭────────────────────────────────────────────────────────────────╮
│ codesnap.nvim/lua/codesnap/config.lua                          │
│────────────────────────────────────────────────────────────────│
│ 24 local code_content = {                                      │
│ 25   content = code,                                           │
│ 26   start_line_number = start_line_number,                    │
│ 27   file_path = get_file_path(static.config.show_workspace),  │
│ 28 }                                                           │
╰────────────────────────────────────────────────────────────────╯
```

As you can see, the ASCII snapshot is just a plain text, without any background, line number, watermark, etc. But it still has key information like code content, line number and file path, which can be useful if someone want to know where the code is from.

Really hope you like this feature! 🤗


### Highlight code block

CodeSnap allows you to take code snapshots with highlights code blocks, we provide two commands for this scenario:

```shell
CodeSnapHighlight # Take code snapshot with highlights code blocks and copy it into the clipboard
CodeSnapSaveHighlight # Take code snapshot with highlights code blocks and save it somewhere
```

#### How to use
For take a code snapshot with highlights code blocks and save it somewhere. First you need to select code which you want to snapshot, then enter the command `CodeSnapSaveHighlight` to open a window show you the selected code which from previous step, now you can select code which you want to highlight _(if any - you can use these without actually highlighting anything)_, finally press the Enter key, CodeSnap will generate a snapshot with highlight blocks and save it in save_path.

![Highlight Demo](/doc/highlight_demo.png)



### Breadcrumbs
Breadcrumbs are really useful tool to display the current snapshot file path, you can enable it by setting `breadcrumbs.enable` to true:

```lua
require("codesnap").setup({
	-- ...
	snapshot_config = {
    -- ...
		code_config = {
			breadcrumbs = {
				enable = true,
				separator = "/",
				color = "#80848b",
				font_family = "CaskaydiaCove Nerd Font",
      }
		}
	}
})
```

Once you enable breadcrumbs, CodeSnap will display the current file path on the top of the snapshot, like this:
![Breadcrumbs Demo](/doc/breadcrumbs_demo.png)


### Line number
Line number is another useful tool to display the current line number of the code, you can enable it by setting `show_line_number` to true:

```lua
require("codesnap").setup({
  -- ...
  show_line_number = true
})
```

![Line Number Demo](/doc/line_number_demo.png)


### Watermark
You can set your own watermark by setting `watermark.content` to your own watermark content.

```lua
require("codesnap").setup({
  -- ...
  watermark = {
    content = "CodeSnap.nvim",
    font_family = "Pacifico",
    color = "#ffffff",
  }
})
```

![Watermark Demo](/doc/watermark_demo.png)

### Custom theme
For CodeSnap.nvim, theme is primarily defined by two parts:
- The background theme
- The code theme

Custom background theme is easy to understand, which is defined by `Background` enum:

```rust
pub enum Background {
    Solid(String),
    Gradient(LinearGradient),
}
```

As you can see, there have two types of background theme:
- Solid(String): A solid color background
- Gradient(LinearGradient): A gradient background

If you prefer solid background, you can just leave it as a solid color string, for example:

```lua
background = "#FFFFFF"
```

Above code will generate a solid white background.

![Cutom background white](/doc/custom_background_solid.png)

CodeSnap.nvim use gradient background by default, you can specify the gradient colors by setting `background.stops` to a table of colors, for example:

```lua
background = {
    start = {
      x = 0,
      y = 0
    },
    end = {
      x = "max",
      y = "max"
    },
    stops = [
      {
        position = 0,
        color = "#EBECB2"
      },
      {
        position = 0.28,
        color = "#F3B0F7"
      },
      {
        position = 0.73,
        color = "#92B5F0"
      },
      {
        position = 0.94,
        color = "#AEF0F8"
      }
    ]
}
```

![Custom background gradient](/doc/custom_background_gradient.png)

Or you prefer transparent background, for example:
```lua
background = "#00000000",
```

![Transparent background](/doc/transparent_demo.png)

#### Custom code theme

For code theme, it's a little bit complex than background theme, you may notice that there only have one config to specify the code theme, which is `theme`, which is a string that represents the code theme name.

```lua
snapshot_config = {
  theme = "candy",
}
```

Above code will use the "candy" theme as the code theme.

"candy" is a built-in theme name, so you can just use it directly.

CodeSnap.nvim use [syntect](https://github.com/trishume/syntect) as code theme engine, which supports Sublime Text theme format, if you want to use your own theme, follow the steps below:

1. Specify `themes_folders` to the path of your own theme files, for example:
```lua
snapshot_config = {
  themes_folders = {
    "~/.config/codesnap/themes",
  },
}
```

2. Put your own theme files in the path you specified, for example:
```
~/.config/codesnap/themes/my_theme.tmTheme
```

3. Use your own theme by setting `theme` to the name of your own theme, for example:
```lua
theme = "my_theme",
```

That's all, now you can use your own theme to take code snapshots.

But you may notice that it's not so easy to use theme you want to use, and if you are VSCode user before, you may know that VSCode has a lot of themes, and you can just search and install the theme you want to use.

Fortunately, CodeSnap.nvim has a built-in theme parser which can convert VSCode theme format to Sublime Text theme format, for example, we want to use the "One Hunter" theme from VSCode (which also is the demo theme in README), we just need to few steps to use it:

1. Construct a "Asset URL", which is a URL that points to the theme file, for example:
```shell
# The prefix "vercel@" is the theme name, you can use any name you want, but it must be provided and unique.
vercel@https://raw.githubusercontent.com/Railly/one-hunter-vscode/refs/heads/main/themes/OneHunter-Vercel-color-theme.json
```

2. Use the "Asset URL" to set `theme` in config, for example:
```lua
theme = "vercel@https://raw.githubusercontent.com/Railly/one-hunter-vscode/refs/heads/main/themes/OneHunter-Vercel-color-theme.json",
```

That's all, now you can use the "One Hunter" theme to take code snapshots.

###  More beautiful themes
The benefit of using "Asset URL" is that you can easily share and store your snapshot config without refer any external resources.

CodeSnap.nvim offers greater flexibility for you to craft your own snapshot theme, you can share your own theme on [Awesome CodeSnap](https://github.com/codesnap-rs/awesome-codesnap?tab=readme-ov-file)

We are looking forward to your amazing snapshot theme! 🤗

## Commands
```shell
CodeSnap # Take a snapshot of the currently selected code and copy the snapshot into the clipboard

CodeSnapSave <path> # Save the snapshot of the currently selected code and save it on the disk

CodeSnapASCII # Take a code snapshot in ASCII format

CodeSnapHighlight # Take code snapshot with highlights code blocks and copy it into the clipboard

CodeSnapCancel # Cancel the current screenshot task
```

Screenshot generation runs in a background Neovim process. You can keep editing
while it runs. Only one screenshot task runs at a time; use `:CodeSnapCancel`
before starting another. Saving writes a temporary image beside the destination
and replaces the destination only after the image is complete.

**Lua**
```lua
local codesnap = require("codesnap")

-- Take a snapshot of the currently selected code and copy the snapshot into the clipboard
local task = codesnap.copy()
```

`copy()`, `save(path)`, `copy_ascii()`, and `copy_highlight()` return a
`vim.async.Task`. They return before rendering finishes; completion or failure is
reported through a notification. Use the task's `on_complete()` method when Lua
code needs to react to completion, or `codesnap.cancel()` to cancel the current task.

## Configuration
Define your custom config using `setup` function
```lua
require("codesnap").setup({...})
```

There is a default config:
```lua
{
  show_line_number = true,
  highlight_color = "#ffffff20",
  show_workspace = true,
  snapshot_config = {
    theme = "candy",
    window = {
      mac_window_bar = true,
      shadow = {
        radius = 20,
        color = "#00000040",
      },
      margin = {
        x = 82,
        y = 82,
      },
      border = {
        width = 1,
        color = "#ffffff30",
      },
      title_config = {
        color = "#ffffff",
        font_family = "Pacifico",
      },
    },
    themes_folders = {},
    fonts_folders = {},
    line_number_color = "#495162",
    command_output_config = {
      prompt = "❯",
      font_family = "CaskaydiaCove Nerd Font",
      prompt_color = "#F78FB3",
      command_color = "#98C379",
      string_arg_color = "#ff0000",
    },
    code_config = {
      font_family = "CaskaydiaCove Nerd Font",
      breadcrumbs = {
        enable = true,
        separator = "/",
        color = "#80848b",
        font_family = "CaskaydiaCove Nerd Font",
      },
    },
    watermark = {
      content = "CodeSnap.nvim",
      font_family = "Pacifico",
      color = "#ffffff",
    },
    background = {
      start = {
        x = 0,
        y = 0,
      },
      ["end"] = {
        x = "max",
        y = 0,
      },
      stops = {
        {
          position = 0,
          color = "#6bcba5",
        },
        {
          position = 1,
          color = "#caf4c2",
        },
      },
    },
  },
}
```

These settings come from the [CodeSnap core fork](https://github.com/so1ve/codesnap).
Refer to its documentation for the rendering configuration.


## Contribution
CodeSnap.nvim is a project that will be maintained for the long term, and we always accepts new contributors, please feel free to submit PR & issues.

The commit message convention of this project is following [commitlint-wizardoc](https://github.com/wizardoc/commitlint-wizardoc).

### Contributors
Thanks to all contributors for their contributions and works they have done.

<img src="CONTRIBUTORS.svg" />

## License
MIT.
