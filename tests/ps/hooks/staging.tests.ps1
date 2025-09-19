# hooks/staging.ps1
BeforeAll {
    $Global:SetDestinationPathListeners = @()
    $Global:TransferWrapupListeners = @()

    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\hooks\staging.ps1' | Resolve-Path
    . $includePath

    Mock Join-Path {
        param([string]$Path, [string]$ChildPath)
        $sep = [System.IO.Path]::DirectorySeparatorChar
        $Path = $Path.TrimEnd($sep)
        $ChildPath = $ChildPath.TrimStart($sep)
        return "$Path$sep$ChildPath"
    }
}
AfterAll {
    $Global:SetDestinationPathListeners = $Null
    $Global:TransferWrapupListeners = $Null
}

Describe "staging" {
    BeforeEach {
        $Script:destinationFilePath = ""
    }
    Context "SetDestinationPathListeners" {
        It "should set the correct path to staging" {
            Mock New-Item { return $null }

            $Script:destinationPath = "Q:\Test\Path\uniqueFileName.txt"

            $Script:destinationPath = . $SetDestinationPathListeners[0] $Script:destinationPath

            $Script:destinationPath | Should -Be "Q:\tmp\staging\"
        }
        It "should attempt to create the staging directory" {
            Mock New-Item { return $null }
            Mock Test-Path { 
                Write-Host "Test Path called for $Path"
                return $False 
            }

            . $SetDestinationPathListeners[0] "Q:\Test\Path\uniqueFileName.txt"

            Assert-MockCalled New-Item -ParameterFilter { $Path -eq "Q:\tmp\staging\" -and $ItemType -eq 'Directory' } -Exactly 1
        }
        It "should not attempt to create the staging directory if it already exists" {
            Mock New-Item { return $null }
            Mock Test-Path { return $True }

            . $SetDestinationPathListeners[0] "Q:\Test\Path\uniqueFileName.txt"

            Assert-MockCalled New-Item -ParameterFilter { $Path -eq "Q:\tmp\staging\" -and $ItemType -eq 'Directory' } -Exactly 0
        }
    }
    Context "TransferWrapupListeners" {
        It "should move file from staging to final destination" {
            $Script:sourcePath = "Q:\tmp\staging"
            $Script:destinationFilePath = "Q:\Test\Path"
            $Script:fileName = "uniqueFileName.txt"

            Mock SendStatusToServer { return $null }
            Mock Move-Item {
                param($LiteralPath, $Destination)
                Write-Host "Move-Item called with Path=$LiteralPath Destination=$Destination"
                return $null
            }
            Mock New-Item { return $null }

            . $TransferWrapupListeners[0] @{
                destination = Join-Path $Script:sourcePath $Script:fileName
            }

            Assert-MockCalled Move-Item -ParameterFilter { $LiteralPath -eq (Join-Path $Script:sourcePath $Script:fileName) -and $Destination -eq (Join-Path $Script:destinationFilePath $Script:fileName) } -Exactly 1
        }
        It "Should set the correct status message" {
            $Script:destinationFilePath = "Q:\Test\Path"
            $Script:message = $Null
            Mock SendStatusToServer {
                param($status)

                $Script:message = $status['message']
            }
            Mock Move-Item { return $null }

            . $TransferWrapupListeners[0] @{
                destination = "Q:\Test\Path\uniqueFileName.txt"
            }

            $Script:message | Should -Be "Moving file from staging"
        }
        It "should attempt to create the final destination directory if it doesn't exist" {
            $Script:destinationFilePath = "Q:\Test\Path"
            $Script:destinationFile = "uniqueFileName.txt"

            Mock SendStatusToServer { return $null }
            Mock Move-Item { return $null }
            Mock Test-Path { return $False }
            Mock New-Item { return $null }

            . $TransferWrapupListeners[0] @{
                destination = Join-Path $Script:destinationPath $Script:destinationFile
            }

            Assert-MockCalled New-Item -ParameterFilter { $Path -eq "Q:\Test\Path" -and $ItemType -eq 'Directory' } -Exactly 1
        }
        It "should not attempt to create the final destination directory if it exists" {
            $Script:destinationFilePath = "Q:\Test\Path"
            $Script:destinationFile = "uniqueFileName.txt"

            Mock SendStatusToServer { return $null }
            Mock Move-Item { return $null }
            Mock Test-Path { return $True }
            Mock New-Item { return $null }

            . $TransferWrapupListeners[0] @{
                destination = Join-Path $Script:destinationPath $Script:destinationFile
            }

            Assert-MockCalled New-Item -ParameterFilter { $Path -eq "Q:\Test\Path" -and $ItemType -eq 'Directory' } -Exactly 0
        }
    }
}