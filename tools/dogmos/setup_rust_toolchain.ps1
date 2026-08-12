#Requires -RunAsAdministrator
<#
	Sets up the Rust toolchain needed to build Dogmos (32-bit, i686-pc-windows-msvc).
	Idempotent: safe to re-run. Installs rustup, MSVC C++ build tools, and LLVM/clang.

	Run in an ELEVATED PowerShell shell. Open a new shell afterwards so PATH and
	LIBCLANG_PATH are picked up before building.
#>

$ErrorActionPreference = 'Stop'

function Test-Installed($name) {
	return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Update-SessionPath {
	$machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
	$user = [Environment]::GetEnvironmentVariable('Path', 'User')
	$env:Path = "$machine;$user"
}

Write-Host '=== Dogmos Rust toolchain setup ===' -ForegroundColor Cyan

if (-not (Test-Installed 'winget')) {
	throw 'winget not found. Install "App Installer" from the Microsoft Store, then re-run.'
}

# 1. MSVC C++ build tools - provides the linker for the *-pc-windows-msvc targets.
if (Test-Path 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools') {
	Write-Host '[skip] VS 2022 Build Tools already present.'
} else {
	Write-Host '[install] VS 2022 Build Tools (C++ workload). This is a large download.'
	winget install --id Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements --override '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
}

# 2. LLVM - bindgen (pulled in by byondapi-sys) needs libclang.
if (Test-Path 'C:\Program Files\LLVM\bin\clang.exe') {
	Write-Host '[skip] LLVM already present.'
} else {
	Write-Host '[install] LLVM'
	winget install --id LLVM.LLVM --accept-package-agreements --accept-source-agreements
}

# 3. rustup
Update-SessionPath
if (Test-Installed 'rustup') {
	Write-Host '[skip] rustup already present; updating.'
	rustup update
} else {
	Write-Host '[install] rustup'
	winget install --id Rustlang.Rustup --accept-package-agreements --accept-source-agreements
	Update-SessionPath
}

# 4. LIBCLANG_PATH, machine scope so TGS/CI shells see it too.
$libclang = 'C:\Program Files\LLVM\bin'
if (Test-Path $libclang) {
	[Environment]::SetEnvironmentVariable('LIBCLANG_PATH', $libclang, 'Machine')
	$env:LIBCLANG_PATH = $libclang
	Write-Host "[env] LIBCLANG_PATH = $libclang"
} else {
	Write-Warning "LLVM bin not found at $libclang - set LIBCLANG_PATH manually."
}

# 5. The 32-bit target. BYOND, rust_g and dreamluau are all i686 here.
Update-SessionPath
rustup default stable
rustup target add i686-pc-windows-msvc

Write-Host ''
Write-Host '=== Verification ===' -ForegroundColor Cyan
rustup --version
cargo --version
rustc --version
if (Test-Path "$libclang\clang.exe") { & "$libclang\clang.exe" --version }
Write-Host ''
Write-Host 'Installed targets:'
rustup target list --installed
Write-Host ''
Write-Host 'Done. Open a NEW shell before building so PATH and LIBCLANG_PATH are picked up.' -ForegroundColor Green
