# vhdl-vscode

VS Code setup for VHDL on Windows and macOS: error checking, go-to-definition, hover and
completion with the [VHDL LS](https://marketplace.visualstudio.com/items?itemName=hbohlin.vhdl-ls)
extension and a modified language server ([Techno453/rust_hdl](https://github.com/Techno453/rust_hdl),
branch `error-recovery`). Unlike the server that ships with the extension, it keeps working in a
file with a syntax error instead of losing everything after it.

On macOS it also includes **FPGA Tools** (`extension/`), with Simulate, Build and Program
buttons for [vivado-on-silicon-mac](https://github.com/Techno453/vivado-on-silicon-mac), which
runs Vivado in a container on Apple Silicon.

## Install

Download `vhdl-vscode-windows.zip` or `vhdl-vscode-mac.zip` from the
[releases](https://github.com/Techno453/vhdl-vscode/releases) and unzip it somewhere permanent.

- **Windows:** double-click `install.cmd` (if Windows asks, choose "More info" → "Run anyway").
  For Vivado outside `C:\Xilinx` and `C:\AMDDesignTools`: `install.cmd -VivadoPath D:\Xilinx\Vivado\2024.2`
- **macOS:** in Terminal, `zsh install.sh`. For Vivado outside
  `~/Desktop/vivado-on-silicon-mac`: `zsh install.sh <folder of Vivado>`

Then restart VS Code. The installer:

- copies the server to `%LOCALAPPDATA%\vhdl_ls\fork` or `~/.local/share/vhdl_ls/fork`
- installs the VHDL LS extension, and on macOS FPGA Tools
- sets `vhdlls.languageServer` to `user` and `vhdlls.languageServerUserPath` to the server in
  your VS Code settings (the old ones are saved as `settings.json.bak`)
- writes `~/.vhdl_ls.toml`, which maps `library unisim;` to Vivado's primitives

Run it again to update or after installing Vivado.

## Per project: vhdl_ls.toml

VHDL LS only knows which files belong together from a `vhdl_ls.toml` in the folder open in VS
Code. To write it, run in the project folder (needs [Python](https://www.python.org/downloads/)):

```
python <unzipped folder>/vhdl_ls_config.py
```

- Each Vivado project (`.xpr`) becomes a library with the VHDL files of the project, so labs
  with their own copies of shared files don't clash. A folder with a `.xdc` but no project uses
  all VHDL files below it.
- A `vhdl_ls.toml` is also written in each project's folder, so opening a single lab works too.
- Without projects, it writes a generic config that picks up `*.vhd` files in the folder.
- Run it again after adding files. Files it (or `fpga vhdl-ls`) didn't write are left alone.

After changing `vhdl_ls.toml`, run "Restart VHDL LS" from the command palette
(Ctrl+Shift+P / Cmd+Shift+P) if errors don't update.

## Troubleshooting

- **No errors or hovers:** check the "VHDL LS" output (View → Output). If it says the server
  wasn't found, run the installer again.
- **"No primary unit 'x' within library 'work'":** the file isn't in `vhdl_ls.toml`; rerun
  `vhdl_ls_config.py`.
- **Back to the stock server:** set "Vhdlls: Language Server" to `embedded` in the settings.

## Development

- `extension/`: FPGA Tools; `python3 extension/build_vsix.py` packages it.
- `install/`: the installers for each platform.
- `bundle.py <windows|mac> <vhdl_ls binary> <rust_hdl checkout>` assembles a release zip in `dist/`.
- `.github/workflows/build.yml` builds the server from the rust_hdl fork (`RUST_HDL_REF`) and
  the bundles on every push; tagging `v*` publishes a release.
