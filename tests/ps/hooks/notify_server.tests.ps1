# hooks/notify_server.ps1
BeforeAll {
    $Global:ChunkTransferredListeners = @()
    $Global:TransferCompleteListeners = @()

    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\core\util.ps1' | Resolve-Path
    . $includePath

    $Global:Config = @{
        modules = @(
            @{
                module_name = 'notify_server'
                variables = @(
                    @{ url = 'http://localhost:3565' }
                )
                enabled = $True
            }
        )
    }

    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\hooks\notify_server.ps1' | Resolve-Path
    . $includePath
}
AfterAll {
    $Global:ChunkTransferredListeners = $Null
    $Global:TransferCompleteListeners = $Null
}
Describe "Notify-Server" {
    BeforeEach {
        $Global:ChunkTransferredListeners = @()
        $Global:TransferCompleteListeners = @()

        $Global:Config = @{
            modules = @(
                @{
                    module_name = 'notify_server'
                    variables = @(
                        @{ url = 'http://localhost:3565' }
                    )
                    enabled = $True
                }
            )
        }

        Remove-Variable -Name NotifyServerIncluded -Scope Script -ErrorAction SilentlyContinue
        $includePath = Join-Path $PSScriptRoot '..\..\..\ps\hooks\notify_server.ps1' | Resolve-Path
        . $includePath
    }
    Context "Initialization" {
        It "should skip inclusion if module is disabled" {
            $Global:ChunkTransferredListeners = @()
            $Global:TransferCompleteListeners = @()

            $Global:Config = @{
                modules = @(
                    @{
                        module_name = 'notify_server'
                        variables = @(
                            @{ url = 'http://localhost:3565' }
                        )
                        enabled = $False
                    }
                )
            }

            Remove-Variable -Name NotifyServerIncluded -Scope Script -ErrorAction SilentlyContinue
            $notifyPath = Join-Path $PSScriptRoot '..\..\..\ps\hooks\notify_server.ps1' | Resolve-Path
            . $notifyPath

            $Global:ChunkTransferredListeners.Count | Should -Be 0
            $Global:TransferCompleteListeners.Count | Should -Be 0
        }
        It "should only include notify_server.ps1 once" {
            Remove-Variable -Name NotifyServerIncluded -Scope Script -ErrorAction SilentlyContinue
            $notifyPath = Join-Path $PSScriptRoot '..\..\..\ps\hooks\notify_server.ps1' | Resolve-Path
            . $notifyPath
            $first = $script:NotifyServerIncluded
            . $notifyPath
            $second = $script:NotifyServerIncluded
            $first | Should -BeTrue
            $second | Should -BeTrue
        }
    }
    Context "ChunkTransferredListeners" {
        It "should add the correct message to status" {
            $Script:message = $Null
            Mock SendStatusToServer {
                param($status)

                $Script:message = $status['message']
            }

            . $Global:ChunkTransferredListeners[0] @{ id = "test123" }

            $Script:message | Should -Be "File transfer in progress..."
        }
    }
    Context "TransferCompleteListeners" {
        It "should add the correct message to status" {
            $Script:message = $Null
            Mock SendStatusToServer {
                param($status)

                $Script:message = $status['message']
            }

            . $Global:TransferCompleteListeners[0] @{ id = "test123" }

            $Script:message | Should -Be "File transfer complete"
        }
        It "should call SendStatusToServer with WaitForJob true" {
            $Script:calledSendStatusWaitForJob = $False
            Mock SendStatusToServer {
                param($status, [bool]$WaitForJob=$False)

                $Script:calledSendStatusWaitForJob = $WaitForJob

                . $function:SendStatusToServer $status $WaitForJob
            }

            . $Global:TransferCompleteListeners[0] @{ id = "test123" }

            $Script:calledSendStatusWaitForJob | Should -Be $True
        }
        It "should wait for the job to complete" {
            $Script:jobCompleted = $False

            Mock Start-Job {
                return @{ Id = 1 } # Dummy job object
            }
            Mock Wait-Job {
                $Script:jobCompleted = $true
            }

            . $Global:TransferCompleteListeners[0] @{ id = "test123" }

            $Script:jobCompleted | Should -Be $True
        }
    }
    Context "SendStatusToServer" {
        It "should call the correct url with the provided id" {
            $Script:calledUrl = $Null
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body, $ContentType)
                $Script:calledUrl = $Uri
            }
            Mock Start-Job {
                param($ScriptBlock, $ArgumentList)
                & $ScriptBlock @ArgumentList
                return @{ Id = 1 } # Dummy job object
            }

            SendStatusToServer @{ id = "abc123"; message = "test" }
            
            $Script:calledUrl | Should -Be "http://localhost:3565/transfer/abc123"
        }
        It "should report an error if the REST call fails" {
            $Script:reportedError = $Null
            Mock Invoke-RestMethod { throw "test failure" }
            Mock Report-Error {
                param(
                    [String]$errorMsg,
                    [bool]$NotifyListeners=$True
                )
                $Script:reportedError = $errorMsg
            }
            Mock Start-Job {
                param($ScriptBlock, $ArgumentList)
                & $ScriptBlock @ArgumentList
                return @{ Id = 1 } # Dummy job object
            }

            $status = @{ id = "abc123"; message = "test" }
            SendStatusToServer $status
            
            $Script:reportedError | Should -Match "Failed to send update"
        }
        It "should send the status as a JSON string encoded in UTF-8" {
            $Script:capturedBody = $Null
            Mock Invoke-RestMethod {
                param($Uri, $method, $body, $ContentType)
                $Script:capturedBody = $Body
            }
            Mock Start-Job {
                param($ScriptBlock, $ArgumentList)
                & $ScriptBlock @ArgumentList
                return @{ Id = 1 } # Dummy job object
            }

            $status = @{ id = "abc123"; message = "some text" }
            SendStatusToServer $status

            $decoded = [System.Text.Encoding]::UTF8.GetString($Script:capturedBody)
            $decoded | Should -Match '"id"\s*:\s*"abc123"'
            $decoded | Should -Match '"message"\s*:\s*"some text"'
        }
        It "should increment the sequence number with each call" {
            $Script:sequence = 0
            
            $Script:sequences = @()
            Mock Invoke-RestMethod {
                param($Uri, $method, $body, $ContentType)
                $decoded = [System.Text.Encoding]::UTF8.GetString($body)
                $json = $decoded | ConvertFrom-Json
                $Script:sequences += $json.sequence
            }
            Mock Start-Job {
                param($ScriptBlock, $ArgumentList)
                & $ScriptBlock @ArgumentList
                return @{ Id = 1 } # Dummy job object
            }

            $status = @{ id = "abc123"; message = "some text" }
            SendStatusToServer $status
            SendStatusToServer $status
            SendStatusToServer $status

            $Script:sequences | Should -Be @(0, 1, 2)
        }
        It "should call Invoke-RestMethod in a background job" {
            $Script:jobStarted = $False
            Mock Start-Job {
                $Script:jobStarted = $True
                return @{ Id = 1 } # Dummy job object
            }
            Mock Invoke-RestMethod {
                param($Uri, $method, $body, $ContentType)
                
                Start-Sleep -Seconds 5
            }

            $status = @{ id = "abc123"; message = "some text" }
            $start = Get-Date
            SendStatusToServer $status
            $end = Get-Date

            ($end - $start).TotalSeconds | Should -BeLessThan 5
            $Script:jobStarted | Should -Be $True
        }
        It "should wait for the job to complete if WaitForJob is true" {
            $Script:jobCompleted = $False
            Mock Start-Job {
                return @{ Id = 1 } # Dummy job object
            }
            Mock Wait-Job {
                $Script:jobCompleted = $True
            }
            Mock Invoke-RestMethod {
                param($Uri, $method, $body, $ContentType)
                
                Start-Sleep -Seconds 3
            }

            $status = @{ id = "abc123"; message = "some text" }
            SendStatusToServer $status -WaitForJob $True

            $Script:jobCompleted | Should -Be $True
        }
    }
}