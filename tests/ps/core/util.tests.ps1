# core/util.ps1
BeforeAll {
    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\core\util.ps1' | Resolve-Path
    . $includePath
    $fakeListeners = @()

    Mock Write-Error {
        param($Message)
        $Script:capturedError = $Message
    }
}

Describe "util" {
    Context "Notify-Listeners" {
        It "should return the same value passed if it doesn't modify it" {
            $fakeListeners += {
                param($paramValue)

                return $paramValue
            }
            $value = "This is the return value"

            $returnValue = Notify-Listeners $fakeListeners -Return $value

            $returnValue | Should -Be $value
        }
        It "should return the changed value when modified" {
            $fakeListeners += {
                param($paramValue)

                return "Changed value"
            }
            $value = "This is the return value"

            $returnValue = Notify-Listeners $fakeListeners -Return $value

            $returnValue | Should -Not -Be $value
            $returnValue | Should -Be "Changed value"
        }
        It "should throw an exception when listeners passed is null" {
            { Notify-Listeners $Null } | Should -Throw -ExpectedMessage "Listeners parameter cannot be null. Pass an empty array if no listeners."
        }
        It "should pass along all the parameters passed to it" {
            $Script:capturedParams = @()

            $fakeListeners += {
                param($param1, $param2, $param3, $param4)

                $Script:capturedParams = @($param1, $param2, $param3, $param4)

                return $param1
            }

            $ret = "return"
            $arg1 = "arg1"
            $arg2 = "arg2"
            $arg3 = "arg3"

            $returnValue = Notify-Listeners $fakeListeners $arg1 $arg2 $arg3 -Return $ret

            $Script:capturedParams[0] | Should -Be $ret
            $Script:capturedParams[1] | Should -Be $arg1
            $Script:capturedParams[2] | Should -Be $arg2
            $Script:capturedParams[3] | Should -Be $arg3

            $returnValue | Should -Be $ret
        }
        It "should call each listener once" {
            $Script:listenerCall1 = 0
            $Script:listenerCall2 = 0
            $Script:listenerCall3 = 0

            $fakeListeners += {
                param($param)

                $Script:listenerCall1 += 1
                
                return $param
            }
            $fakeListeners += {
                param($param)

                $Script:listenerCall2 += 1

                return $param
            }
            $fakeListeners += {
                param($param)

                $Script:listenerCall3 += 1

                return $param
            }

            $returnValue = Notify-Listeners $fakeListeners -Return "return"

            $Script:listenerCall1 | Should -Be 1
            $Script:listenerCall2 | Should -Be 1
            $Script:listenerCall3 | Should -Be 1
        }
        It "should modify the return value on each call" {
            $fakeListeners += {
                param($param)

                $param += 1
                
                return $param
            }
            $fakeListeners += {
                param($param)

                $param += 2

                return $param
            }
            $fakeListeners += {
                param($param)

                $param += 3

                return $param
            }

            $returnValue = Notify-Listeners $fakeListeners -Return 0

            $returnValue | Should -Be 6
        }
    }
    Context "Report-Error" {
        It "writes the error to Write-Error" {
            $errors = & {
                $Error.Clear()
                Report-Error "This is an error message that is very unique, like very" 2>$Null
                $Error
            }

            # because it's mocked, we can't check $errors[0] directly
            # so we check what our mock captured
            $Script:capturedError | Should -Match "This is an error message that is very unique, like very"
        }
        It "calls listeners" {
            $Script:listener1called = $False
            $Script:listener2called = $False
            $Global:ReportErrorListeners = @()

            $Global:ReportErrorListeners += {
                param($msg)

                $Script:listener1called = $msg
            }
            $Global:ReportErrorListeners += {
                param($msg)

                $Script:listener2called = $msg
            }

            Report-Error "This is the error message" 2>$Null

            $Script:listener1called | Should -Be "This is the error message" 
            $Script:listener2called | Should -Be "This is the error message"
        }
        It "doesn't call listeners if flag is set" {
            $Script:listener1called = $False
            $Script:listener2called = $False
            $Global:ReportErrorListeners = @()

            $Global:ReportErrorListeners += {
                param($msg)

                $Script:listener1called = $msg
            }
            $Global:ReportErrorListeners += {
                param($msg)

                $Script:listener2called = $msg
            }

            Report-Error "This is the error message" $False 2>$Null

            $Script:listener1called | Should -Be $False
            $Script:listener2called | Should -Be $False
        }
    }
    Context Module-Enabled {
        It "returns $False when module config is empty" {
            $Global:Config = @{
                modules = @()
            }

            $result = Module-Enabled "nonexistentmodule"

            $result | Should -Be $False
        }
        It "returns $False when that module is not in config" {
            $Global:Config = @{
                modules = @(
                    @{
                        module_name = "somemodule"
                        enabled = $True
                    }
                )
            }

            $result = Module-Enabled "nonexistentmodule"

            $result | Should -Be $False
        }
        It "returns $False when module is disabled in config" {
            $Global:Config = @{
                modules = @(
                    @{
                        module_name = "disabledmodule"
                        enabled = $False
                    }
                )
            }

            $result = Module-Enabled "disabledmodule"

            $result | Should -Be $False
        }
        It "returns $True when module is enabled in config" {
            $Global:Config = @{
                modules = @(
                    @{
                        module_name = "enabledmodule"
                        enabled = $True
                    }
                )
            }

            $result = Module-Enabled "enabledmodule"

            $result | Should -Be $True
        }
        It "returns $True when module is enabled in config and enabled is not explicitly set to $False" {
            $Global:Config = @{
                modules = @(
                    @{
                        module_name = "enabledmodule"
                    }
                )
            }

            $result = Module-Enabled "enabledmodule"

            $result | Should -Be $True
        }
    }
    Context Get-Module-Variables {
        It "returns $Null when module config is empty" {
            $Global:Config = @{
                modules = @()
            }

            $result = Get-Module-Variables "nonexistentmodule"

            $result | Should -Be $Null
        }
        It "returns $Null when that module is not in config" {
            $Global:Config = @{
                modules = @(
                    @{
                        module_name = "somemodule"
                        enabled = $True
                    }
                )
            }

            $result = Get-Module-Variables "nonexistentmodule"

            $result | Should -Be $Null
        }
        It "returns an empty hashtable when module has no variables" {
            $Global:Config = @{
                modules = @(
                    @{
                        module_name = "novarsmodule"
                        enabled = $True
                    }
                )
            }

            $result = Get-Module-Variables "novarsmodule"

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }
        It "returns a hashtable of variables when module has variables" {
            $Global:Config = @{
                modules = @(
                    @{
                        module_name = "varsmodule"
                        enabled = $True
                        variables = @(
                            @{ var1 = "value1" },
                            @{ var2 = 2 },
                            @{ var3 = $True }
                        )
                    }
                )
            }

            $result = Get-Module-Variables "varsmodule"

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 3
            $result["var1"] | Should -Be "value1"
            $result["var2"] | Should -Be 2
            $result["var3"] | Should -Be $True
        }
        It "should substitute environment variables in values" {
            $env:TEST_ENV_VAR = "envvalue"
            $Global:Config = @{
                modules = @(
                    @{
                        module_name = "envvarsmodule"
                        enabled = $True
                        variables = @(
                            @{ var1 = "value1" },
                            @{ var2 = "env:TEST_ENV_VAR" }
                        )
                    }
                )
            }

            $result = Get-Module-Variables "envvarsmodule"

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 2
            $result["var1"] | Should -Be "value1"
            $result["var2"] | Should -Be "envvalue"
        }
    }
    Context Convert-ToBytes {
        It "should convert strings with units to bytes correctly" {
            $result = Convert-ToBytes "15B"
            $result | Should -Be 15

            $result = Convert-ToBytes "1KB"
            $result | Should -Be 1024

            $result = Convert-ToBytes "1MB"
            $result | Should -Be 1MB

            $result = Convert-ToBytes "1GB"
            $result | Should -Be 1GB

            $result = Convert-ToBytes "1TB"
            $result | Should -Be 1TB

            $result = Convert-ToBytes "1PB"
            $result | Should -Be 1PB
        }
        It "should convert numbers to bytes correctly" {
            $result = Convert-ToBytes 2048
            $result | Should -Be 2048
        }
        It "should throw an error for invalid input" {
            { Convert-ToBytes "invalid" } | Should -Throw -ExpectedMessage "Invalid size format: invalid"
        }
        It "should throw an error for null input" {
            { Convert-ToBytes $Null } | Should -Throw -ExpectedMessage "Size is null"
        }
        It "should handle lowercase units" {
            $result = Convert-ToBytes "15b"
            $result | Should -Be 15

            $result = Convert-ToBytes "1kb"
            $result | Should -Be 1024

            $result = Convert-ToBytes "1mb"
            $result | Should -Be 1MB

            $result = Convert-ToBytes "1gb"
            $result | Should -Be 1GB

            $result = Convert-ToBytes "1tb"
            $result | Should -Be 1TB

            $result = Convert-ToBytes "1pb"
            $result | Should -Be 1PB
        }
        It "should throw an error for non-string, non-numeric input" {
            try {
                Convert-ToBytes @()
                throw "Did not throw"
            } catch {
                $_.Exception.Message | Should -Be "Invalid size format: System.Object[]"
            }
        }
        It "should handle numbers with decimal points" {
            $result = Convert-ToBytes "1.5KB"
            $result | Should -Be 1536

            $result = Convert-ToBytes "2.75MB"
            $result | Should -Be (2.75 * 1MB)
        }
    }
}