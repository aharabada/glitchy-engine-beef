<#
.SYNOPSIS
    Builds the Beef DLL and the C# benchmark, then runs it.

.PARAMETER BeefBuild
    BeefBuild executable to use. Defaults to the one on PATH.
    For the custom fork: -BeefBuild D:\Development\Git\Beef\IDE\dist\BeefBuild.exe

.PARAMETER Stubs
    Don't benchmark. Call every variant once and list which calls made the JIT generate an IL marshalling stub.

.PARAMETER BenchmarkArgs
    Passed through to BenchmarkDotNet, e.g. --filter *Scale* or --job short
#>
param(
    [string] $BeefBuild = "beefbuild",
    [switch] $Stubs,
    [Parameter(ValueFromRemainingArguments)] [string[]] $BenchmarkArgs
)

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$dll = Join-Path $root "build\Release_Win64\BeefDemoLib\BeefDemoLib.dll"
$benchDll = Join-Path $root "Bench\bin\Release\net10.0\Bench.dll"

Write-Host "--- Building Beef DLL ---" -ForegroundColor Cyan
& $BeefBuild "-workspace=$root" -platform=Win64 -config=Release
if ($LASTEXITCODE -ne 0) { throw "beefbuild failed with exit code $LASTEXITCODE" }
if (-not (Test-Path $dll)) { throw "Expected Beef output not found: $dll" }

Write-Host "--- Building C# benchmark ---" -ForegroundColor Cyan
dotnet build (Join-Path $root "Bench\Bench.csproj") -c Release --nologo -v q
if ($LASTEXITCODE -ne 0) { throw "dotnet build failed with exit code $LASTEXITCODE" }

if ($Stubs)
{
    $summary = Join-Path $root "Bench\bin\jit-summary.txt"

    # The JIT appends to an existing file.
    Remove-Item $summary -ErrorAction Ignore

    # TieredCompilation=0 so every method is jitted exactly once and shows up in a stable order.
    $env:DOTNET_JitStdOutFile = $summary
    $env:DOTNET_JitDisasmSummary = "1"
    $env:DOTNET_TieredCompilation = "0"

    try
    {
        dotnet $benchDll --stubs
    }
    finally
    {
        Remove-Item Env:DOTNET_JitStdOutFile, Env:DOTNET_JitDisasmSummary, Env:DOTNET_TieredCompilation
    }

    Write-Host "--- Jitted call wrappers (an IL_STUB_PInvoke line belongs to the wrapper above it) ---" -ForegroundColor Cyan
    Select-String -Path $summary -Pattern "Calls:(?!Init)|IL_STUB" |
        ForEach-Object { $_.Line.Trim() -replace '^\d+:\s*JIT compiled ', '' }
    return
}

Write-Host "--- Running benchmarks ---" -ForegroundColor Cyan
Push-Location (Join-Path $root "Bench")
try
{
    if ($BenchmarkArgs) { dotnet $benchDll @BenchmarkArgs }
    else { dotnet $benchDll }
}
finally
{
    Pop-Location
}
