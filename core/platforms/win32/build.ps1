<#
.SYNOPSIS
    Bareos Windows Build Script for Visual Studio 2026
.DESCRIPTION
    Builds Bareos using MSVC v143 toolset on VS 2026.
    Qt is expected to be installed externally (e.g. via aqtinstall).

    Prerequisites:
    - Visual Studio 2026 with C++ Desktop workload and v143 build tools
    - Git:    C:\Program Files\Git
    - CMake:  3.31.x (standalone, not VS-bundled 4.2 which has issues)
    - Qt:     6.x for MSVC 2022 64-bit (e.g. C:\Qt\6.10.3\msvc2022_64)
    - vcpkg:  C:\vcpkg (matching builtin-baseline in vcpkg.json)

    Install Qt via aqtinstall (no Qt account needed):
      pip install aqtinstall
      aqt install-qt windows desktop 6.10.3 win64_msvc2022_64 --outputdir C:\Qt

    Install CMake 3.31:
      Download from https://github.com/Kitware/CMake/releases
      Extract to C:\cmake

.PARAMETER Clean
    Remove build directory and vcpkg buildtrees before building
.PARAMETER ConfigureOnly
    Only run CMake configure, skip the build step
.PARAMETER Branch
    Git branch to checkout before building
.PARAMETER QtDir
    Path to Qt installation (default: C:\Qt\6.10.3\msvc2022_64)
.PARAMETER CmakeDir
    Path to CMake bin directory (default: C:\cmake\cmake-3.31.6-windows-x86_64\bin)
.PARAMETER VcVarsVer
    MSVC toolset version (default: 14.44)
#>

param(
    [switch]$Clean,
    [switch]$ConfigureOnly,
    [string]$Branch,
    [string]$QtDir = "C:\Qt\6.10.3\msvc2022_64",
    [string]$CmakeDir = "C:\cmake\cmake-3.31.6-windows-x86_64\bin",
    [string]$VcVarsVer = "14.44"
)

$ErrorActionPreference = "Stop"

# --- Paths ---
$RepoRoot  = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$BuildDir  = "$RepoRoot\build"
$VcpkgRoot = "C:\vcpkg"
$CmakeBin  = "$CmakeDir\cmake.exe"
$NinjaBin  = "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe"
$VcVarsAll = "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat"

# --- Check prerequisites ---
$missing = @()
foreach ($p in @($CmakeBin, $NinjaBin, $VcVarsAll, "$VcpkgRoot\vcpkg.exe")) {
    if (-not (Test-Path $p)) { $missing += $p }
}
if (-not (Test-Path $QtDir)) {
    $missing += "$QtDir (install via: aqt install-qt windows desktop 6.10.3 win64_msvc2022_64 --outputdir C:\Qt)"
}
if ($missing.Count -gt 0) {
    Write-Error "Missing components:`n$($missing -join "`n")"
    exit 1
}
Write-Host "All prerequisites OK" -ForegroundColor Green

# --- Branch ---
if ($Branch) {
    $env:PATH += ";C:\Program Files\Git\cmd"
    Push-Location $RepoRoot
    & git fetch origin $Branch 2>&1 | Out-Null
    & git checkout $Branch 2>&1
    Pop-Location
}

# --- Clean ---
if ($Clean) {
    Write-Host "Cleaning..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $BuildDir -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "C:\v" -ErrorAction SilentlyContinue
}

# --- vcpkg overlay triplet (force v143 toolset) ---
$TripletDir = "$RepoRoot\triplets"
New-Item -ItemType Directory -Path $TripletDir -Force | Out-Null
@"
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)

# Use v143 (VS 2022) toolset. VS 2026 v145 defaults to Clang-CL which
# breaks vcpkg builds (/Z7 interpreted as filename). MSVC 14.44 in
# VS 2026 is registered as v143 and works correctly.
set(VCPKG_PLATFORM_TOOLSET v143)

# Only build release vcpkg libraries to avoid D8050 debug record
# length issues. See: https://stackoverflow.com/questions/26547214
set(VCPKG_BUILD_TYPE release)
"@ | Set-Content "$TripletDir\x64-windows.cmake"

# --- Short temp paths (avoid D8050 path length issue) ---
New-Item -ItemType Directory -Path "C:\tmp" -Force | Out-Null

# --- Generate batch script (vcvarsall requires cmd) ---
$cmakePath = Split-Path $CmakeBin
$ninjaPath = Split-Path $NinjaBin

$buildStep = ""
if (-not $ConfigureOnly) {
    $buildStep = "if %errorlevel% equ 0 `"$CmakeBin`" --build `"$BuildDir`" -j %NUMBER_OF_PROCESSORS% -- -k0"
}

$batch = @"
@echo off
call "$VcVarsAll" amd64 -vcvars_ver=$VcVarsVer

REM Resolve full path to cl.exe so vcpkg sub-shells can find it
for %%i in (cl.exe) do set CL_FULL_PATH=%%~`$PATH:i

REM Find ATL headers from newest MSVC toolset that has them
set ATL_INCLUDE=
set ATL_LIB=
for /d %%d in ("C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\*") do (
  if exist "%%d\atlmfc\include\atlbase.h" (
    set "ATL_INCLUDE=%%d\atlmfc\include"
    set "ATL_LIB=%%d\atlmfc\lib\x64"
  )
)
if defined ATL_INCLUDE (
  set "INCLUDE=%ATL_INCLUDE%;%INCLUDE%"
  set "LIB=%ATL_LIB%;%LIB%"
  echo ATL found
) else (
  echo WARNING: ATL not found - hyper-v plugin will not build
)

set PATH=$cmakePath;C:\Program Files\Git\cmd;$ninjaPath;%PATH%
set VCPKG_ROOT=$VcpkgRoot
set TMP=C:\tmp
set TEMP=C:\tmp
set CC=%CL_FULL_PATH%
set CXX=%CL_FULL_PATH%
cd /d $RepoRoot
"$CmakeBin" -S . -B "$BuildDir" -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_TOOLCHAIN_FILE=$VcpkgRoot\scripts\buildsystems\vcpkg.cmake ^
  -DCMAKE_MAKE_PROGRAM="$NinjaBin" ^
  -DCMAKE_MSVC_DEBUG_INFORMATION_FORMAT=ProgramDatabase ^
  -DVCPKG_INSTALL_OPTIONS="--x-buildtrees-root=C:\v\bt" ^
  -DVCPKG_OVERLAY_TRIPLETS=$TripletDir ^
  -DCMAKE_PREFIX_PATH=$QtDir ^
  -DCMAKE_C_COMPILER=cl.exe ^
  -DCMAKE_CXX_COMPILER=cl.exe ^
  -DENABLE_SYSTEMTESTS=OFF ^
  -DUSE_RELATIVE_PATHS=ON
$buildStep
"@

$batchFile = "$env:TEMP\bareos_build.bat"
$batch | Set-Content $batchFile

Write-Host ""
Write-Host "Starting build..." -ForegroundColor Green
Write-Host "  Repo:    $RepoRoot" -ForegroundColor Cyan
Write-Host "  Toolset: MSVC $VcVarsVer (v143)" -ForegroundColor Cyan
Write-Host "  CMake:   $($CmakeBin)" -ForegroundColor Cyan
Write-Host "  Qt:      $QtDir" -ForegroundColor Cyan
Write-Host ""

cmd /c $batchFile

# --- Result ---
$exes = Get-ChildItem "$BuildDir\core\src" -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue
if ($exes.Count -gt 0) {
    Write-Host "`nBuilt $($exes.Count) executables:" -ForegroundColor Green
    foreach ($exe in $exes) {
        Write-Host "  $($exe.Name)"
    }
} else {
    Write-Warning "No executables found - build may have failed"
}
