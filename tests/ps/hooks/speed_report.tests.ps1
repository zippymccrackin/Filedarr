# hooks/speed_report.ps1
BeforeAll {
    $Global:SetStatusInformationListeners = @()

    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\core\util.ps1' | Resolve-Path
    . $includePath
    
    $Global:Config = @{
        modules = @(
            @{
                module_name = 'speed_report'
                variables = @(
                    @{ intervalCheckSeconds = 5 }
                )
                enabled = $True
            }
        )
    }
    
    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\hooks\speed_report.ps1' | Resolve-Path
    . $includePath
}
AfterAll {
    $Global:SetStatusInformationListeners = $Null
}

Describe "speed_report" {
    BeforeEach {
        # Clear stats before each test
        $Script:recentStats = @()

        $Global:Config = @{
            modules = @(
                @{
                    module_name = 'speed_report'
                    variables = @(
                        @{ intervalCheckSeconds = 5 }
                    )
                    enabled = $True
                }
            )
        }
        $includePath = Join-Path $PSScriptRoot '..\..\..\ps\hooks\speed_report.ps1' | Resolve-Path
        . $includePath
    }
    Context "Initialization" {
        It "should skip inclusion if module is disabled" {
            $Global:SetStatusInformationListeners = @()

            $Global:Config = @{
                modules = @(
                    @{
                        module_name = 'speed_report'
                        variables = @(
                            @{ intervalCheckSeconds = 5 }
                        )
                        enabled = $False
                    }
                )
            }

            $includePath = Join-Path $PSScriptRoot '..\..\..\ps\hooks\speed_report.ps1' | Resolve-Path
            . $includePath

            $Global:SetStatusInformationListeners.Count | Should -Be 0
        }
    }
    Context "SetStatusInformationListeners" {
        It "should calculate speed and eta correctly for a normal case" {
            $now = Get-Date
            $status1 = @{
                timestamp   = $now.AddSeconds(-5)
                transferred = 0
                total       = 100MB
            }

            $status2 = @{
                timestamp   = $now
                transferred = 50MB
                total       = 100MB
            }

            # Simulate two status updates to populate recentStats
            $null = & $SetStatusInformationListeners[0] $status1
            $result = & $SetStatusInformationListeners[0] $status2

            $result.Keys | Should -Contain 'eta'
            $result.Keys | Should -Contain 'speed_mb_s'

            [double]$expectedSpeedMB = 10.0  # 50MB over 5 seconds
            [string]$expectedETA = [TimeSpan]::FromSeconds(5).ToString("hh\:mm\:ss")

            $result['speed_mb_s'] | Should -BeGreaterThan 9.9
            $result['speed_mb_s'] | Should -BeLessThan 10.1
            $result['eta'] | Should -Be $expectedETA
        }

        It "should set speed and eta to 0 when only one sample exists" {
            $now = Get-Date
            $status = @{
                timestamp   = $now
                transferred = 50MB
                total       = 100MB
            }

            $result = & $SetStatusInformationListeners[0] $status

            $result['speed_mb_s'] | Should -Be 0
            $result['eta'] | Should -Be ([TimeSpan]::FromSeconds(0).ToString("hh\:mm\:ss"))
        }

        It "should remove samples older than 5 seconds" {
            $now = Get-Date

            $Script:recentStats = @(
                [PSCustomObject]@{ time = $now.AddSeconds(-10); bytes = 0 },
                [PSCustomObject]@{ time = $now.AddSeconds(-4); bytes = 50MB }
            )

            $status = @{
                timestamp   = $now
                transferred = 100MB
                total       = 200MB
            }

            $result = & $SetStatusInformationListeners[0] $status

            $Script:recentStats.Count | Should -Be 2  # Only 2 recent stats remain
            $result['speed_mb_s'] | Should -BeGreaterThan 0
        }

        It "should not throw when recentStats is null or non-array" {
            $Script:recentStats = $null

            $status = @{
                timestamp   = Get-Date
                transferred = 0
                total       = 100MB
            }

            { & $SetStatusInformationListeners[0] $status } | Should -Not -Throw
        }

        It "should return 0 for recentSpeed if deltaTime is not greater than 0" {
            $now = Get-Date

            $Script:recentStats = @(
                [PSCustomObject]@{ time = $now; bytes = 50MB }
                [PSCustomObject]@{ time = $now; bytes = 100MB }
            )

            $status = @{
                timestamp   = $now
                transferred = 100MB
                total       = 200MB
            }

            $result = & $SetStatusInformationListeners[0] $status

            $result['eta'] | Should -Be ([TimeSpan]::FromSeconds(0).ToString("hh\:mm\:ss"))
            $result['speed_mb_s'] | Should -Be 0
        }
    }
}