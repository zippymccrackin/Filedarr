# core/util.ps1
BeforeAll {
    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\core\util.ps1' | Resolve-Path
    . $includePath
    $fakeListeners = @()
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
                Report-Error "This is an error message" 2>$Null
                $Error
            }

            $errors[0].ToString() | Should -Match "This is an error message"
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
}