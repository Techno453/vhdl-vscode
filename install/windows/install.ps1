# Sets up VS Code for VHDL on Windows:
# - installs the VHDL LS extension (hbohlin.vhdl-ls)
# - installs a VHDL LS server built from Techno453/rust_hdl (error-recovery branch), which
#   keeps working in files with syntax errors, and points the extension at it
# - writes %USERPROFILE%\.vhdl_ls.toml so that "library unisim;" resolves to Vivado's primitives
#
# Usage: install.cmd, or powershell -ExecutionPolicy Bypass -File install.ps1 [-VivadoPath C:\Xilinx\Vivado\2024.2]
param([string]$VivadoPath = "")

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding $false
$marker = "# Written by install.ps1 of vhdl-vscode-windows"

# Language server
$dest = Join-Path $env:LOCALAPPDATA "vhdl_ls\fork"
Write-Host "Copying the VHDL LS server to $dest"
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item -Recurse (Join-Path $here "vhdl_ls\*") $dest
# Drop the "downloaded from the internet" mark from the unzipped files
try { Get-ChildItem -Recurse -File $dest | Unblock-File } catch { }
$exe = Join-Path $dest "bin\vhdl_ls.exe"

# Extension
$code = Get-Command code -ErrorAction SilentlyContinue
if ($code) { $code = $code.Source }
else {
	foreach ($candidate in @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd", "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd")) {
		if (Test-Path $candidate) { $code = $candidate; break }
	}
}
if ($code) {
	Write-Host "Installing the VHDL LS extension"
	& $code --install-extension hbohlin.vhdl-ls --force
} else {
	Write-Warning "VS Code's 'code' command was not found. Install the extension 'VHDL LS' (hbohlin.vhdl-ls) from the Extensions view."
}

# VS Code settings: use the server installed above instead of the embedded one.
# Edited as text, since settings.json may contain comments.
function Set-Setting([string]$text, [string]$key, [string]$value) {
	$json = '"' + $key + '": "' + ($value -replace '\\', '\\') + '"'
	$existing = New-Object regex ('"' + [regex]::Escape($key) + '"\s*:\s*"[^"]*"')
	if ($existing.IsMatch($text)) {
		return $existing.Replace($text, { param($m) $json })
	}
	$open = New-Object regex '\{'
	return $open.Replace($text, { param($m) "{`n    $json," }, 1)
}

$settingsDir = Join-Path $env:APPDATA "Code\User"
$settings = Join-Path $settingsDir "settings.json"
New-Item -ItemType Directory -Force $settingsDir | Out-Null
$text = ""
if (Test-Path $settings) {
	$text = [System.IO.File]::ReadAllText($settings)
	Copy-Item $settings "$settings.bak" -Force
	Write-Host "Updating $settings (backup in settings.json.bak)"
} else {
	Write-Host "Writing $settings"
}
if ($text -notmatch '\{') { $text = "{`n}`n" }
$text = Set-Setting $text "vhdlls.languageServerUserPath" $exe
$text = Set-Setting $text "vhdlls.languageServer" "user"
# An empty object gets a trailing comma from the insertion, which VS Code would warn about
$text = $text -replace ',\s*\}\s*$', "`n}`n"
[System.IO.File]::WriteAllText($settings, $text, $utf8)

# Vivado's primitive library (unisim)
$vcomp = "data\vhdl\src\unisims\unisim_VCOMP.vhd"
$vivado = $null
if ($VivadoPath) {
	if (-not (Test-Path (Join-Path $VivadoPath $vcomp))) { throw "$VivadoPath does not contain $vcomp" }
	$vivado = $VivadoPath
} else {
	$candidates = @()
	if ($env:XILINX_VIVADO) { $candidates += Get-Item $env:XILINX_VIVADO -ErrorAction SilentlyContinue }
	foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Root) {
		foreach ($pattern in @("Xilinx\Vivado\*", "Xilinx\*\Vivado", "AMDDesignTools\*\Vivado", "AMD\*\Vivado")) {
			$candidates += Get-ChildItem -Directory (Join-Path $drive $pattern) -ErrorAction SilentlyContinue
		}
	}
	# Newest version first, by the version in the path (e.g. 2024.2)
	$vivado = $candidates |
		Where-Object { Test-Path (Join-Path $_.FullName $vcomp) } |
		Sort-Object { [regex]::Match($_.FullName, '\d{4}\.\d').Value } -Descending |
		Select-Object -First 1 -ExpandProperty FullName
}

$userConfig = Join-Path $env:USERPROFILE ".vhdl_ls.toml"
if (-not $vivado) {
	Write-Warning "Vivado was not found, so 'library unisim;' won't resolve. After installing Vivado, run again with -VivadoPath <folder of Vivado, e.g. C:\Xilinx\Vivado\2024.2>."
} elseif ((Test-Path $userConfig) -and -not ([System.IO.File]::ReadAllText($userConfig).Contains($marker))) {
	Write-Warning "$userConfig was not written by this installer, not changing it."
} else {
	$unisims = (Join-Path $vivado "data\vhdl\src\unisims") -replace '\\', '/'
	$toml = @"
$marker
# User configuration for the VHDL LS extension: Xilinx's primitive library,
# so that "library unisim; use unisim.vcomponents.all;" resolves.
[libraries]
unisim.files = [
	"$unisims/unisim_VPKG.vhd",
	"$unisims/unisim_VCOMP.vhd",
]
unisim.is_third_party = true
"@
	[System.IO.File]::WriteAllText($userConfig, ($toml -replace "`r`n", "`n"), $utf8)
	Write-Host "Wrote $userConfig for Vivado in $vivado"
}

Write-Host ""
Write-Host "Done. Restart VS Code (or run 'Developer: Reload Window')."
Write-Host "In each project folder, run:  python `"$here\vhdl_ls_config.py`""
