BeforeAll {
    . (Join-Path $PSScriptRoot '../../../ps/core/util.ps1')
}
Describe 'Notify server hooks' {
    BeforeEach {
        $Global:ChunkTransferredListeners = @()
        $Global:TransferCompleteListeners = @()
        $Global:Config = @{ modules = @(@{ module_name='notify_server'; enabled=$true; variables=@(@{url='http://localhost:3565'}) }) }
        Remove-Variable NotifyServerIncluded -Scope Script -ErrorAction SilentlyContinue
        . (Join-Path $PSScriptRoot '../../../ps/hooks/notify_server.ps1')
    }
    It 'registers hooks only once' {
        . (Join-Path $PSScriptRoot '../../../ps/hooks/notify_server.ps1')
        $Global:ChunkTransferredListeners.Count | Should -Be 1
        $Global:TransferCompleteListeners.Count | Should -Be 1
    }
    It 'skips disabled module' {
        $Global:ChunkTransferredListeners = @()
        $Global:TransferCompleteListeners = @()
        $Global:Config.modules[0].enabled = $false
        . (Join-Path $PSScriptRoot '../../../ps/hooks/notify_server.ps1')
        $Global:ChunkTransferredListeners.Count | Should -Be 0
        $Global:TransferCompleteListeners.Count | Should -Be 0
    }
    It 'reports progress without waiting' {
        Mock SendStatusToServer {}
        $status = @{id='test'}
        & $Global:ChunkTransferredListeners[0] $status
        $status.message | Should -Be 'File transfer in progress...'
        Should -Invoke SendStatusToServer -Times 1 -ParameterFilter { -not $WaitForJob }
    }
    It 'waits for final status delivery' {
        Mock SendStatusToServer {}
        $status = @{id='test'}
        & $Global:TransferCompleteListeners[0] $status
        $status.message | Should -Be 'File transfer complete'
        Should -Invoke SendStatusToServer -Times 1 -ParameterFilter { $WaitForJob }
    }
}
