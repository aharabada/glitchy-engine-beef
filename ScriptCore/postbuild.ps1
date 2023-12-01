# Definiere die Parameter $sourceDir und $destinationDir
param
(
    [string]$sourceDir,
    [string]$destinationDir
)

if (-not (Test-Path -Path $sourceDir))
{
    Write-Host "Source directory $sourceDir doesn't exist."
    exit
}

# Create destination if necessary
if (-not (Test-Path -Path $destinationDir))
{
    New-Item -ItemType Directory -Force -Path $destinationDir
}
    
# Gebe die Pfadinformationen aus
Write-Host "Kopiere Dateien von $sourceDir nach $destinationDir"

# Copy all files from source folder to the destination folder
Copy-Item -Path "$sourceDir\*" -Destination $destinationDir -Recurse