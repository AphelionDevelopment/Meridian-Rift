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

function Invoke-Checked([string]$FilePath, [string[]]$Arguments) {
	& $FilePath @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "$FilePath failed with exit code $LASTEXITCODE"
	}
}

function Find-VisualStudioBuildTools {
	$vswhere = Get-Command vswhere.exe -ErrorAction SilentlyContinue
	if ($vswhere) {
		$installationPath = & $vswhere.Source -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
		if ($LASTEXITCODE -eq 0 -and $installationPath) { return $installationPath | Select-Object -First 1 }
	}
	$programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
	if ($programFilesX86) {
		$candidate = Join-Path $programFilesX86 'Microsoft Visual Studio\2022\BuildTools'
		if (Test-Path -LiteralPath $candidate -PathType Container) { return $candidate }
	}
	return $null
}

function Find-LlvmBin {
	$clang = Get-Command clang.exe -ErrorAction SilentlyContinue
	if ($clang) { return Split-Path -Parent $clang.Source }
	$llvmHome = [Environment]::GetEnvironmentVariable('LLVM_HOME')
	if ($llvmHome) {
		$candidate = Join-Path $llvmHome 'bin'
		if (Test-Path -LiteralPath (Join-Path $candidate 'clang.exe') -PathType Leaf) { return $candidate }
	}
	$programFiles = [Environment]::GetEnvironmentVariable('ProgramFiles')
	if ($programFiles) {
		$candidate = Join-Path $programFiles 'LLVM\bin'
		if (Test-Path -LiteralPath (Join-Path $candidate 'clang.exe') -PathType Leaf) { return $candidate }
	}
	return $null
}

Write-Host '=== Dogmos Rust toolchain setup ===' -ForegroundColor Cyan

if (-not (Test-Installed 'winget')) {
	throw 'winget not found. Install "App Installer" from the Microsoft Store, then re-run.'
}

# 1. MSVC C++ build tools - provides the linker for the *-pc-windows-msvc targets.
if (Find-VisualStudioBuildTools) {
	Write-Host '[skip] VS 2022 Build Tools already present.'
} else {
	Write-Host '[install] VS 2022 Build Tools (C++ workload). This is a large download.'
	Invoke-Checked 'winget' @('install', '--id', 'Microsoft.VisualStudio.2022.BuildTools', '--accept-package-agreements', '--accept-source-agreements', '--override', '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
}

# 2. LLVM - bindgen (pulled in by byondapi-sys) needs libclang.
if (Find-LlvmBin) {
	Write-Host '[skip] LLVM already present.'
} else {
	Write-Host '[install] LLVM'
	Invoke-Checked 'winget' @('install', '--id', 'LLVM.LLVM', '--accept-package-agreements', '--accept-source-agreements')
}

# 3. rustup
Update-SessionPath
if (Test-Installed 'rustup') {
	Write-Host '[skip] rustup already present; updating.'
	Invoke-Checked 'rustup' @('update')
} else {
	Write-Host '[install] rustup'
	Invoke-Checked 'winget' @('install', '--id', 'Rustlang.Rustup', '--accept-package-agreements', '--accept-source-agreements')
	Update-SessionPath
}

# 4. LIBCLANG_PATH, machine scope so TGS/CI shells see it too.
$libclang = Find-LlvmBin
if ($libclang) {
	[Environment]::SetEnvironmentVariable('LIBCLANG_PATH', $libclang, 'Machine')
	$env:LIBCLANG_PATH = $libclang
	Write-Host "[env] LIBCLANG_PATH = $libclang"
} else {
	Write-Warning "LLVM bin not found at $libclang - set LIBCLANG_PATH manually."
}

# 5. The 32-bit target. BYOND, rust_g and dreamluau are all i686 here.
Update-SessionPath
Invoke-Checked 'rustup' @('default', 'stable')
Invoke-Checked 'rustup' @('target', 'add', 'i686-pc-windows-msvc')

Write-Host ''
Write-Host '=== Verification ===' -ForegroundColor Cyan
rustup --version
cargo --version
rustc --version
if ($libclang) { & (Join-Path $libclang 'clang.exe') --version }
Write-Host ''
Write-Host 'Installed targets:'
rustup target list --installed
Write-Host ''
Write-Host 'Done. Open a NEW shell before building so PATH and LIBCLANG_PATH are picked up.' -ForegroundColor Green
