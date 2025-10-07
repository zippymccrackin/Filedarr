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
    }
    Context "SendStatusToServer" {
        It "should call the correct url with the provided id" {
            $Script:calledUrl = $Null
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Body, $ContentType)
                $Script:calledUrl = $Uri
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

            $status = @{ id = "abc123"; message = "some text" }
            SendStatusToServer $status

            $decoded = [System.Text.Encoding]::UTF8.GetString($Script:capturedBody)
            $decoded | Should -Match '"id"\s*:\s*"abc123"'
            $decoded | Should -Match '"message"\s*:\s*"some text"'
        }
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