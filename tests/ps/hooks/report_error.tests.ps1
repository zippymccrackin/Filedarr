# hooks/report_error.ps1
BeforeAll {
    $Global:ReportErrorListeners = @()

    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\hooks\report_error.ps1' | Resolve-Path
    . $includePath
}
AfterAll {
    $Global:ReportErrorListeners = $Null
}
Describe "report_error" {
    Context "ReportErrorListeners" {
        It "should call SendErrorToServer with the provided error" {
            $Script:errorMessage = $Null
            Mock SendErrorToServer {
                param($msg)

                $Script:errorMessage = $msg
            }

            Notify-Listeners $GLobal:ReportErrorListeners "This is the error message"

            $Script:errorMessage | Should -Be "This is the error message"
        }
    }
    Context "SendErrorToServer" {
        It "should send the message encoded in UTF-8" {
            $Script:capturedBody = $Null
            Mock Invoke-RestMethod {
                param($Uri, $method, $body, $ContentType)
                $Script:capturedBody = $Body
            }

            SendErrorToServer "This is an error message"

            $decoded = [System.Text.Encoding]::UTF8.GetString($Script:capturedBody)
            $decoded | Should -Match '"message"\s*:\s*"This is an error message"'
        }
        It "should report error when exception is thrown and not notify listeners" {
            Mock Invoke-RestMethod {
                throw "Exception thrown"
            }
            $Script:msgSent = $Null
            $Script:listenersFlag = $True
            Mock Report-Error {
                param(
                    [String]$errorMsg,
                    [bool]$NotifyListeners=$True
                )

                $Script:msgSent = $errorMsg
                $Script:listenersFlag = $NotifyListeners
            }

            SendErrorToServer "This is an error message"

            $Script:msgSent | Should -Be "Failed to send error: Exception thrown"
            $Script:listenersFlag | Should -Be $False
        }
    }
}