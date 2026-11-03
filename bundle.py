#!/usr/bin/env python3
# Assembles dist/vhdl-vscode-<platform>.zip, which is unzipped and installed on the user's machine:
# the VHDL LS server with its standard libraries, the installer and the vhdl_ls.toml generator,
# and on macOS the FPGA Tools extension.
#
# Usage: python3 bundle.py <windows|mac> <vhdl_ls binary> <rust_hdl checkout>

import shutil
import subprocess
import sys
from pathlib import Path

here = Path(__file__).parent
platform, server, rust_hdl = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
if platform not in ("windows", "mac"):
	sys.exit("platform must be windows or mac")

name = f"vhdl-vscode-{platform}"
dist = here / "dist"
target = dist / name
shutil.rmtree(target, ignore_errors=True)
target.mkdir(parents=True)

# Same layout as rust_hdl's releases: the server finds ../vhdl_libraries next to bin
(target / "vhdl_ls" / "bin").mkdir(parents=True)
shutil.copy2(server, target / "vhdl_ls" / "bin" / ("vhdl_ls.exe" if platform == "windows" else "vhdl_ls"))
shutil.copytree(rust_hdl / "vhdl_libraries", target / "vhdl_ls" / "vhdl_libraries",
	ignore=shutil.ignore_patterns(".*"))
shutil.copy2(rust_hdl / "LICENSE.txt", target / "vhdl_ls" / "LICENSE.txt")

for path in (here / "install" / platform).iterdir():
	shutil.copy2(path, target / path.name)
shutil.copy2(here / "vhdl_ls_config.py", target / "vhdl_ls_config.py")
shutil.copy2(here / "README.md", target / "README.md")

if platform == "mac":
	vsix = subprocess.run([sys.executable, here / "extension" / "build_vsix.py"],
		check=True, capture_output=True, text=True).stdout.strip()
	shutil.move(here / "extension" / vsix, target / vsix)

# make_archive keeps the permissions, so install.sh and vhdl_ls stay executable
archive = shutil.make_archive(str(dist / name), "zip", dist, name)
print(archive)
