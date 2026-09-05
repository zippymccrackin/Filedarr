# Compile only against the current PowerShell runtime's trusted reference files.
# Sonarr/Radarr's working directories can contain a different runtime's System.dll.
if (-not ('Filedarr.CopyWorker' -as [type])) {
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        $frameworkDirectory = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
        $workerReferences = @('mscorlib.dll', 'System.dll', 'System.Core.dll') | ForEach-Object {
            Join-Path $frameworkDirectory $_
        }
    } else {
        $referenceDirectory = Join-Path $PSHOME 'ref'
        $workerReferences = [System.IO.Directory]::GetFiles($referenceDirectory, '*.dll')
    }
    Add-Type -Path (Join-Path $PSScriptRoot 'CopyWorker.cs') -ReferencedAssemblies $workerReferences -ErrorAction Stop
}
