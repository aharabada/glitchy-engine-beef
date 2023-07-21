Write-Output "Preparing repository for development..."

# Change working directory to repository root
Push-Location ($PSScriptRoot + "/..")

$RootDirectory = $(Get-Location);

# Note: When adding new scripts make sure to use "Set-Location $RootDirectory" if the script changes the working directory

# Prepare NetHost
Push-Location "GlitchyEngine/vendor/NetHostBeef"
Invoke-Expression -Command "./downloadNethost.ps1"
Pop-Location

# Return to original working directory
Pop-Location
