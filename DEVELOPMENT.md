# Developing the fork

The Neovim plugin is maintained and released independently in `so1ve/codesnap.nvim`.
Its releases do not depend on an upstream plugin PR or an upstream core release;
the generator pins a tested Git revision of `so1ve/codesnap`.

`generator/Cargo.toml` selects the core revision, and `generator/Cargo.lock` locks
its dependencies. Cargo fetches the backend directly when building the generator.
`v3.0.0-beta.1` is a prerelease. Its installation examples in [README.md](README.md)
use the release tag.

The asynchronous implementation requires a Neovim nightly with the public
`vim.async` API. Check with `nvim --headless --clean -l` and a script that asserts
`vim.async ~= nil`, or use `:lua print(vim.async)` interactively. A nightly build
from before that API was introduced is insufficient.

PNG saves and Linux clipboard copies use the backend's `SnapshotConfig::write_png`
to render and encode strips directly into a file. The worker hands that file to
`wl-copy` or `xclip` through stdin, without loading its contents into Lua. macOS and
Windows use `raw_data()` for their native clipboard APIs, which require a complete
RGBA image. Rebuild the generator after updating the pinned core revision.

## Build and test the generator

From the `codesnap.nvim` checkout, build the generator:

```sh
cargo build --release --locked --manifest-path generator/Cargo.toml
```

On Linux x86_64, provision that library for the loader:

```sh
mkdir -p lua/libs
cp generator/target/release/libgenerator.so lua/libs/linux-x86_64_generator.so
python - <<'PY'
import pathlib
import tomllib

version = tomllib.loads(pathlib.Path("project.toml").read_text())["project"]["version"]
pathlib.Path("lua/libs/.version").write_text(version + "\n")
PY
```

For other platforms, use the filename returned by
`lua/codesnap/fetch.lua` and the native extension produced by Cargo. Test with a
Neovim nightly whose runtime path contains this checkout, then exercise both
`:CodeSnap` and `:CodeSnapSave` on a small selection and a large selection. Test
the clipboard in a real desktop session. No GitHub download is needed when the
library and version marker match.

## Prepare a release

1. When upgrading the backend, set `codesnap.rev` in `generator/Cargo.toml` to the
   full commit hash of the tested, published core revision. Update the lock with
   `cargo update --manifest-path generator/Cargo.toml --workspace`, then update
   `cargoLock.outputHashes."codesnap-0.13.4"` in `flake.nix` for that Git source.
   Adjust the hash key if the core package version changes.
2. Set a new fork version in `project.toml`, validate the plugin against the locked
   core and a supported Neovim nightly, and prepare a matching `v<version>` tag.
   Do not reuse an upstream version for different native binaries.
3. Publish the plugin changes and tag only when that publication is authorized.
   A `v*` tag starts `Release`, which creates the release using `GITHUB_TOKEN`,
   then calls `Build` to compile and attach the platform libraries. A hyphenated
   version is marked as a prerelease. No personal access token is required.
4. Confirm that every platform attachment finished uploading before directing
   users to install that release.

The downloader reads the version from `project.toml` and retrieves assets only
from `https://github.com/so1ve/codesnap.nvim/releases/download/v<version>/`.
Creating a GitHub release manually does not trigger the build workflow; use the
tag publication flow above.
