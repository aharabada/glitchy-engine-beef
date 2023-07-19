# Definiere die Parameter $sourceDir und $destinationDir
param
(
    [string]$sourceDir,
    [string]$destinationDir
)

# Überprüfe, ob die Verzeichnisse existieren
if ((Test-Path -Path $sourceDir) -and (Test-Path -Path $destinationDir))
{
    
    # Gebe die Pfadinformationen aus
    Write-Host "Kopiere Dateien von $sourceDir nach $destinationDir"
    
    # Kopiere alle Dateien vom Quell- zum Zielverzeichnis
    Get-ChildItem -Path $sourceDir -File | ForEach-Object { Copy-Item -Path $_.FullName -Destination $destinationDir }

}
else
{
    Write-Host "Ein oder beide Verzeichnisse existieren nicht."
}