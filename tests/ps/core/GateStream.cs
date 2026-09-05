using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
public class GateStream : MemoryStream {
    public bool BlockReads, BlockWrites;
    public readonly TaskCompletionSource<bool> ReadGate = new TaskCompletionSource<bool>();
    public readonly TaskCompletionSource<bool> WriteGate = new TaskCompletionSource<bool>();
    public GateStream(byte[] content) { base.Write(content, 0, content.Length); Position = 0; }
    public override async Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken token) {
        if (BlockReads) await ReadGate.Task.ConfigureAwait(false);
        return await base.ReadAsync(buffer, offset, count, token).ConfigureAwait(false);
    }
    public override async Task WriteAsync(byte[] buffer, int offset, int count, CancellationToken token) {
        if (BlockWrites) await WriteGate.Task.ConfigureAwait(false);
        await base.WriteAsync(buffer, offset, count, token).ConfigureAwait(false);
    }
}
