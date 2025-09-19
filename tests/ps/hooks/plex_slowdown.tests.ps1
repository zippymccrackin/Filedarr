# hooks/plex_slowdown.ps1
BeforeAll {
    $Global:ChunkSizeListeners = @()
    $Global:DelayMsListeners = @()

    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\hooks\plex_slowdown.ps1' | Resolve-Path
    . $includePath
    # Include Util for Notify-Listeners
    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\core\util.ps1' | Resolve-Path
    . $includePath
}
AfterAll {
    $Global:ChunkSizeListeners = $Null
    $Global:DelayMsListeners = $Null
}

Describe "plex_shutdown" {
    Context "ChunkSizeListeners" {
        It "should call Update-PlexStreamingStatus" {
            $Script:called = $False
            Mock Update-PlexStreamingStatus {
                $Script:called = $True
            }

            Notify-Listeners $Global:ChunkSizeListeners -Return 3MB

            $Script:called | Should -Be $True
        }
        It "return what it's given when Update-PlexStreamingStatus is false" {
            Mock Update-PlexStreamingStatus {
                $Script:plexStreaming = $False
            }

            $response = Notify-Listeners $Global:ChunkSizeListeners -Return 100MB

            $response | Should -Be 100MB
        }
        It "sets return to 1MB if Update-PlexStreamingStatus is true" {
            Mock Update-PlexStreamingStatus {
                $Script:plexStreaming = $True
            }

            $response = Notify-Listeners $Global:ChunkSizeListeners -Return 100MB

            $response | Should -Be 1MB
        }
    }
    Context "DelayMsListeners" {
        It "should call Update-PlexStreamingStatus" {
            $Script:called = $False
            Mock Update-PlexStreamingStatus {
                $Script:called = $True
            }

            Notify-Listeners $Global:DelayMsListeners -Return 0

            $Script:called | Should -Be $True
        }
        It "return what it's given when Update-PlexStreamingStatus is false" {
            Mock Update-PlexStreamingStatus {
                $Script:plexStreaming = $False
            }

            $response = Notify-Listeners $Global:DelayMsListeners -Return 0

            $response | Should -Be 0
        }
        It "sets return to 150 if Update-PlexStreamingStatus is true" {
            Mock Update-PlexStreamingStatus {
                $Script:plexStreaming = $True
            }

            $response = Notify-Listeners $Global:DelayMsListeners -Return 0

            $response | Should -Be 150
        }
    }
    Context "Update-PlexStreamingStatus" {
        It "should set the lastPlexUpdate when first called" {
            $Script:lastPlexUpdate = $Null

            Update-PlexStreamingStatus

            $Script:lastPlexUpdate | Should -Not -Be $Null
        }
        It "should not check Plex status when there's less than 5 seconds between lastPlexUpdate and now" {
            $Script:called = $False

            Mock Invoke-WebRequest {
                $Script:called = $True
            }

            $Script:lastPlexUpdate = Get-Date
            Update-PlexStreamingStatus

            $Script:called | Should -Be $False
        }
        It "should check Plex status when there's 5 seconds between lastPlexUpdate and now" {
            $Script:called = $False

            Mock Invoke-WebRequest {
                $Script:called = $True
            }

            $Script:lastPlexUpdate = (Get-Date).AddSeconds(-6)
            Update-PlexStreamingStatus

            $Script:called | Should -Be $True
        }
        It "should set plexStreaming to false if Plex URL does not have <Video> tag" {
            Mock Invoke-WebRequest {
                return @{
                    Content = "<NoVideo></NoVideo>"
                }
            }

            $Script:plexStreaming = $True
            $Script:lastPlexUpdate = (Get-Date).AddSeconds(-6)
            Update-PlexStreamingStatus

            $Script:plexStreaming | Should -Be $False
        }
        It "should set plexStreaming to true if Plex URL does have Video tag" {
            Mock Invoke-WebRequest {
                return @{
                    Content = "<Video id='hi'></Video>"
                }
            }

            $Script:plexStreaming = $False
            $Script:lastPlexUpdate = (Get-Date).AddSeconds(-6)
            Update-PlexStreamingStatus

            $Script:plexStreaming | Should -Be $True
        }
        It "should set plexStreaming to false if there's an error fetching Plex URL" {
            Mock Invoke-WebRequest {
                throw "Exception"
            }

            $Script:plexStreaming = $True
            $Script:lastPlexUpdate = (Get-Date).AddSeconds(-6)
            Update-PlexStreamingStatus 3>$Null

            $Script:plexStreaming | Should -Be $False
        }
        It "should update lastPlexUpdate at the end of the Plex check" {
            Mock Invoke-WebRequest {
                return @{
                    Content = "<Video id='hi'></Video>"
                }
            }
            $Script:lastPlexUpdate = (Get-Date).AddSeconds(-6)
            $value = $Script:lastPlexUpdate
            Update-PlexStreamingStatus

            $Script:lastPlexUpdate | Should -BeGreaterThan $value
        }
        It "should not update lastPlexUpdate if not inside the Plex check" {
            Mock Invoke-WebRequest {
                return @{
                    Content = "<Video id='hi'></Video>"
                }
            }
            $Script:lastPlexUpdate = (Get-Date).AddSeconds(-2)
            $value = $Script:lastPlexUpdate

            Update-PlexStreamingStatus

            $Script:lastPlexUpdate | Should -Be $value
        }
    }
}