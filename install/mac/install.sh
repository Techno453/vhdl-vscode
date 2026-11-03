#!/bin/zsh

# Sets up VS Code for VHDL on macOS:
# - installs the VHDL LS extension (hbohlin.vhdl-ls) and, if bundled, FPGA Tools
# - installs a VHDL LS server built from Techno453/rust_hdl (error-recovery branch), which
#   keeps working in files with syntax errors, and points the extension at it
# - writes ~/.vhdl_ls.toml so that "library unisim;" resolves to Vivado's primitives
#
# Usage: zsh install.sh [folder of Vivado, e.g. ~/Desktop/vivado-on-silicon-mac/Xilinx/Vivado/2024.2]

set -e
here=${0:A:h}
marker="# Written by install.sh of vhdl-vscode"

# Language server
dest=~/.local/share/vhdl_ls/fork
echo "Copying the VHDL LS server to $dest"
rm -rf "$dest"
mkdir -p "$dest"
cp -R "$here/vhdl_ls/" "$dest/"
# Downloaded binaries are quarantined, which would stop VS Code from starting the server
xattr -dr com.apple.quarantine "$dest" 2>/dev/null || true
exe="$dest/bin/vhdl_ls"

# Extensions
code=$(command -v code || true)
if [[ -z $code && -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]
then
	code="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi
if [[ -n $code ]]
then
	echo "Installing the VHDL LS extension"
	"$code" --install-extension hbohlin.vhdl-ls --force
	for vsix in "$here"/fpga-tools-*.vsix(N)
	do
		echo "Installing FPGA Tools"
		"$code" --install-extension "$vsix" --force
	done
else
	echo "VS Code's 'code' command was not found. Install the extension 'VHDL LS' (hbohlin.vhdl-ls) from the Extensions view." >&2
fi

# VS Code settings: use the server installed above instead of the embedded one.
# Edited as text, since settings.json may contain comments.
settings_dir=~/Library/Application\ Support/Code/User
settings="$settings_dir/settings.json"
mkdir -p "$settings_dir"
if [[ -f $settings ]]
then
	cp "$settings" "$settings.bak"
	echo "Updating $settings (backup in settings.json.bak)"
	grep -q '{' "$settings" || echo '{}' > "$settings"
else
	echo "Writing $settings"
	echo '{}' > "$settings"
fi
function set_setting {
	KEY=$1 VALUE=$2 perl -0777 -i -pe '
		(my $value = $ENV{VALUE}) =~ s/([\\"])/\\$1/g;
		my $json = "\"$ENV{KEY}\": \"$value\"";
		my $key = quotemeta $ENV{KEY};
		s/"$key"\s*:\s*"[^"]*"/$json/ or s/\{/{\n    $json,/;
	' "$settings"
}
set_setting vhdlls.languageServerUserPath "$exe"
set_setting vhdlls.languageServer user
# An empty object gets a trailing comma from the insertion, which VS Code would warn about
perl -0777 -i -pe 's/,\s*\}\s*\z/\n}\n/' "$settings"

# Vivado's primitive library (unisim)
vcomp=data/vhdl/src/unisims/unisim_VCOMP.vhd
vivado=
if [[ -n $1 ]]
then
	if [[ ! -f $1/$vcomp ]]
	then
		echo "$1 does not contain $vcomp" >&2
		exit 1
	fi
	vivado=${1:A}
else
	# Newest version first; vivado-on-silicon-mac installs Vivado into its Xilinx folder
	for candidate in ~/Desktop/vivado-on-silicon-mac/Xilinx/Vivado/*(N/On) ~/vivado-on-silicon-mac/Xilinx/Vivado/*(N/On)
	do
		if [[ -f $candidate/$vcomp ]]
		then
			vivado=$candidate
			break
		fi
	done
fi

user_config=~/.vhdl_ls.toml
if [[ -z $vivado ]]
then
	echo "Vivado was not found, so 'library unisim;' won't resolve. After installing Vivado, run again with its folder, e.g. zsh install.sh ~/Desktop/vivado-on-silicon-mac/Xilinx/Vivado/2024.2" >&2
elif [[ -f $user_config ]] && ! grep -qF -- "$marker" "$user_config"
then
	echo "$user_config was not written by this installer, not changing it." >&2
else
	unisims="$vivado/data/vhdl/src/unisims"
	cat > "$user_config" << EOF
$marker
# User configuration for the VHDL LS extension: Xilinx's primitive library,
# so that "library unisim; use unisim.vcomponents.all;" resolves.
[libraries]
unisim.files = [
	"$unisims/unisim_VPKG.vhd",
	"$unisims/unisim_VCOMP.vhd",
]
unisim.is_third_party = true
EOF
	echo "Wrote $user_config for Vivado in $vivado"
fi

echo
echo "Done. Restart VS Code (or run 'Developer: Reload Window')."
echo "In each project folder, run:  python3 \"$here/vhdl_ls_config.py\""
