# core/listeners.ps1
# Reset listeners to make sure they load
$Global:ChunkSizeListeners = $Null
$Global:DelayMsListeners = $Null
$Global:ChunkTransferredListeners = $Null
$Global:TransferWrapupListeners = $Null
$Global:TransferCompleteListeners = $Null
$Global:SetDestinationPathListeners = $Null
$Global:SetDestinationFilenameListeners = $Null
$Global:SetStatusInformationListeners = $Null
$Global:ReportErrorListeners = $Null

BeforeAll {
    $includePath = Join-Path $PSScriptRoot '..\..\..\ps\core\listeners.ps1' | Resolve-Path
    . $includePath
}
AfterAll {
    $Global:ChunkSizeListeners = $Null
    $Global:DelayMsListeners = $Null
    $Global:ChunkTransferredListeners = $Null
    $Global:TransferWrapupListeners = $Null
    $Global:TransferCompleteListeners = $Null
    $Global:SetDestinationPathListeners = $Null
    $Global:SetDestinationFilenameListeners = $Null
    $Global:SetStatusInformationListeners = $Null
    $Global:ReportErrorListeners = $Null
}

Describe "ChunkSizeListeners" {
    It "should be empty and not null" {
        $listeners = $Global:ChunkSizeListeners
        $listeners.Length | Should -Be 0
    }
    It "should have global scope" {
        (Get-Variable -Name 'ChunkSizeListeners' -Scope Global).name | Should -Not -BeNull
    }
}
Describe "DelayMsListeners" {
    It "should be empty and not null" {
        $DelayMsListeners.Length | Should -Be 0
    }
    It "should have global scope" {
        (Get-Variable -Name 'DelayMsListeners' -Scope Global).name | Should -Not -BeNull
    }
}
Describe "ChunkTransferredListeners" {
    It "should be empty and not null" {
        $ChunkTransferredListeners.Length | Should -Be 0
    }
    It "should have global scope" {
        (Get-Variable -Name 'ChunkTransferredListeners' -Scope Global).name | Should -Not -BeNull
    }
}
Describe "TransferWrapupListeners" {
    It "should be empty and not null" {
        $TransferWrapupListeners.Length | Should -Be 0
    }
    It "should have global scope" {
        (Get-Variable -Name 'TransferWrapupListeners' -Scope Global).name | Should -Not -BeNull
    }
}
Describe "TransferCompleteListeners" {
    It "should be empty and not null" {
        $TransferCompleteListeners.Length | Should -Be 0
    }
    It "should have global scope" {
        (Get-Variable -Name 'TransferCompleteListeners' -Scope Global).name | Should -Not -BeNull
    }
}
Describe "SetDestinationPathListeners" {
    It "should be empty and not null" {
        $SetDestinationPathListeners.Length | Should -Be 0
    }
    It "should have global scope" {
        (Get-Variable -Name 'SetDestinationPathListeners' -Scope Global).name | Should -Not -BeNull
    }
}
Describe "SetDestinationFilenameListeners" {
    It "should be empty and not null" {
        $SetDestinationFilenameListeners.Length | Should -Be 0
    }
    It "should have global scope" {
        (Get-Variable -Name 'SetDestinationFilenameListeners' -Scope Global).name | Should -Not -BeNull
    }
}
Describe "SetStatusInformationListeners" {
    It "should be empty and not null" {
        $SetStatusInformationListeners.Length | Should -Be 0
    }
    It "should have global scope" {
        (Get-Variable -Name 'SetStatusInformationListeners' -Scope Global).name | Should -Not -BeNull
    }
}
Describe "ReportErrorListeners" {
    It "should be empty and not null" {
        $ReportErrorListeners.Length | Should -Be 0
    }
    It "should have global scope" {
        (Get-Variable -Name 'ReportErrorListeners' -Scope Global).name | Should -Not -BeNull
    }
}