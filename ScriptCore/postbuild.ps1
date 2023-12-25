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

Write-Host "Copying Files from $sourceDir to $destinationDir"

# Copy all files from source folder to the destination folder
Get-ChildItem -Path $sourceDir -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Substring((Get-Item $sourceDir).FullName.Length).TrimStart('\')
    $destPath = Join-Path $destinationDir $relativePath
    if (-not (Test-Path -Path (Split-Path -Path $destPath -Parent)))
    {
        New-Item -ItemType Directory -Force -Path (Split-Path -Path $destPath -Parent)
    }
    try {
        Copy-Item -Path $_.FullName -Destination $destPath -ErrorAction Stop
    } catch {
        Write-Warning "Konnte die Datei $_.FullName nicht kopieren: $_.Exception.Message"
    }
}
