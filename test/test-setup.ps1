$DebugPreference = "Continue"

# Get the full path to the directory this script is in
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define 'source' and 'destination' directory paths relative to the script
$sourceDir = Join-Path $scriptDir 'source'
$destinationDir = Join-Path $scriptDir 'destination'

# Create the 'source' directory if it doesn't exist
if (-not (Test-Path $sourceDir)) {
    New-Item -ItemType Directory -Path $sourceDir | Out-Null
}

# Generate a random filename with some content
$randomName = [guid]::NewGuid().ToString() + '.txt'
$sourceFilePath = Join-Path $sourceDir $randomName
"Test content for $randomName" | Set-Content -Path $sourceFilePath

# Set environment variables
$env:Sonarr_SourcePath = $sourceFilePath
$env:Sonarr_DestinationPath = Join-Path $destinationDir $randomName

# Path to the import script
$importScriptPath = Join-Path $scriptDir '..\Filedarr-Importer.ps1'

# Normalize path
$importScriptPath = Resolve-Path $importScriptPath

# Invoke the import script
& $importScriptPath