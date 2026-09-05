BeforeAll {
    Add-Type -Path (Join-Path $PSScriptRoot '../../../ps/core/CopyWorker.cs')
    Add-Type -Path (Join-Path $PSScriptRoot 'GateStream.cs')
    . (Join-Path $PSScriptRoot '../../../ps/core/diagnostics.ps1')
    function Wait-CopyDone($worker) {
        $deadline = [datetime]::UtcNow.AddSeconds(5)
        while (-not $worker.Snapshot().Done -and [datetime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 20 }
        $worker.Snapshot().Done | Should -BeTrue
    }
}
Describe 'Copy worker live diagnostics' {
    It 'reports source waits while no bytes can move and recovers without losing data' {
        $source = [GateStream]::new([byte[]](1,2,3,4))
        $dest = [GateStream]::new([byte[]]@())
        $source.BlockReads = $true
        $worker = [Filedarr.CopyWorker]::new()
        try {
            $worker.StartStreams($source, $dest, 4, 2, 0)
            Start-Sleep -Milliseconds 300
            $snapshot = $worker.Snapshot()
            $snapshot.Done | Should -BeFalse
            $snapshot.ReadPendingSeconds | Should -BeGreaterThan 0.1
            (Get-CopyDiagnostics $snapshot 0.1).summary | Should -Match 'waiting for source read'
            $source.ReadGate.SetResult($true)
            Wait-CopyDone $worker
            $worker.Snapshot().Error | Should -BeNullOrEmpty
            $dest.ToArray() | Should -Be ([byte[]](1,2,3,4))
        } finally { $source.ReadGate.TrySetResult($true); $worker.Cancel(); $source.Dispose(); $dest.Dispose() }
    }
    It 'reads ahead while a destination write is stalled and exposes the write wait' {
        $source = [GateStream]::new([byte[]](1,2,3,4))
        $dest = [GateStream]::new([byte[]]@())
        $dest.BlockWrites = $true
        $worker = [Filedarr.CopyWorker]::new()
        try {
            $worker.StartStreams($source, $dest, 4, 2, 0)
            Start-Sleep -Milliseconds 300
            $snapshot = $worker.Snapshot()
            $snapshot.ReadOperations | Should -Be 2
            $snapshot.Bytes | Should -Be 0
            $snapshot.WritePendingSeconds | Should -BeGreaterThan 0.1
            (Get-CopyDiagnostics $snapshot 0.1).summary | Should -Match 'waiting for destination write'
            $dest.WriteGate.SetResult($true)
            Wait-CopyDone $worker
            $dest.ToArray() | Should -Be ([byte[]](1,2,3,4))
        } finally { $dest.WriteGate.TrySetResult($true); $worker.Cancel(); $source.Dispose(); $dest.Dispose() }
    }
    It 'queues competing copies to a destination volume and releases the slot' {
        $source = Join-Path $TestDrive 'source.bin'
        $first = Join-Path $TestDrive 'first.bin'
        $second = Join-Path $TestDrive 'second.bin'
        [IO.File]::WriteAllBytes($source, [byte[]](1,2,3,4,5,6,7,8))
        $worker = [Filedarr.CopyWorker]::new()
        $other = [Filedarr.CopyWorker]::new()
        try {
            $worker.Start($source, $first, 8, 2, 200, 1)
            Start-Sleep -Milliseconds 150
            $other.Start($source, $second, 8, 2, 0, 1)
            Start-Sleep -Milliseconds 150
            $other.Snapshot().Phase | Should -Be 'queued'
            $worker.SetControls(3, 0)
            Wait-CopyDone $worker
            Wait-CopyDone $other
            $worker.Snapshot().Error | Should -BeNullOrEmpty
            $other.Snapshot().Error | Should -BeNullOrEmpty
            [IO.File]::ReadAllBytes($first) | Should -Be ([IO.File]::ReadAllBytes($source))
            [IO.File]::ReadAllBytes($second) | Should -Be ([IO.File]::ReadAllBytes($source))
        } finally { $worker.Cancel(); $other.Cancel() }
    }
    It 'reports size mismatch as failure' {
        $source = [GateStream]::new([byte[]](1,2))
        $dest = [GateStream]::new([byte[]]@())
        $worker = [Filedarr.CopyWorker]::new()
        $worker.StartStreams($source, $dest, 10, 2, 0)
        Wait-CopyDone $worker
        $worker.Snapshot().Phase | Should -Be 'failed'
        $worker.Snapshot().Error | Should -Match 'size verification'
        $source.Dispose(); $dest.Dispose()
    }
}
