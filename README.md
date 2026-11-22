# wit-releases

Prebuilt binaries of [Wiimms ISO Tools](https://wit.wiimm.de/) (`wit`, `wwt`, `wdf`)
built from pinned commits of [Wiimm/wiimms-iso-tools](https://github.com/Wiimm/wiimms-iso-tools),
published as GitHub releases that [mise](https://mise.jdx.dev)'s `github:` backend can install.

```sh
mise use github:<owner>/wit-releases@3.05a
```

| asset | built on |
|---|---|
| `wit-v<ver>-linux-x86_64.tar.gz` | ubuntu-24.04, statically linked |
| `wit-v<ver>-linux-aarch64.tar.gz` | ubuntu-24.04-arm, statically linked |
| `wit-v<ver>-macos-arm64.tar.gz` | macos-15 |
| `wit-v<ver>-macos-x86_64.tar.gz` | macos-15-intel |
| `wit-v<ver>-windows-x86_64.zip` | windows-latest + Cygwin (best effort, bundles Cygwin DLLs) |

Archives contain `bin/` and `share/wit/` (title databases, found relative to the binaries).
`wfuse` is not built.

## Releasing a new upstream version

Upstream has no tags. [Renovate](renovate.json) tracks its `master` branch through `UPSTREAM_MASTER`
in `xmake.lua` and opens a PR when it moves, which is your cue to release. Renovate also keeps the
SHA-pinned GitHub Actions and the xmake version in `.mise.toml` up to date.

1. Add the upstream commit to `VERSIONS` in [`xmake.lua`](xmake.lua) (newest first):
   ```lua
   {"3.06", "<upstream commit sha>"},
   ```
2. Commit, then tag and push:
   ```sh
   git tag v3.06 && git push origin main v3.06
   ```
   [`release.yml`](.github/workflows/release.yml) builds every platform and creates the release.
   A suffixed tag (`v3.06-rc1`) builds the same upstream version as a **prerelease**, which is handy for dry runs.
   Re-running the workflow (Actions → release → *Run workflow* with the tag) replaces the assets of an existing release.

## How it builds

- `xmake.lua` defines an xmake package `wiimms-iso-tools` whose versions map to upstream commit shas.
  xmake clones upstream at that sha, drops [`port/`](port) into its `project/` dir and builds it.
  The `dist` target then packs `build/dist/wit-v<ver>-<os>-<arch>.tar.gz`.
- [`port/xmake.lua`](port/xmake.lua) replaces upstream's GNU make build (it needs gawk and probes `/usr/include`).
  [`port/codegen.lua`](port/codegen.lua) generates `version.h` and the `text-files/*.inc` includes.
  The gen-ui output (`src/ui/ui-*.c`) is committed upstream and used as is.
- Windows uses upstream's own Makefile inside Cygwin, since upstream only supports Windows through Cygwin.

### Local build

```sh
mise install            # xmake, pinned in .mise.toml
xmake f -y [--wit_version=3.05a]
xmake -y                # -> build/dist/*.tar.gz
```

Linux needs `libncurses-dev` (static `libtinfo.a`). xmake fetches zlib itself.

xmake caches the built package. After editing `port/`, force a rebuild:

```sh
xmake require --force -y wiimms-iso-tools && xmake -y
```
