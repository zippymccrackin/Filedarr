using System;
using System.IO;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using System.Security.Cryptography;
using System.Text;

namespace Filedarr {
    public sealed class CopySnapshot {
        public string Phase { get; set; }
        public string Error { get; set; }
        public long Bytes { get; set; }
        public double ElapsedSeconds { get; set; }
        public double ActiveSeconds { get; set; }
        public double PhaseSeconds { get; set; }
        public double IdleSeconds { get; set; }
        public double ReadPendingSeconds { get; set; }
        public double WritePendingSeconds { get; set; }
        public double ReadSeconds { get; set; }
        public double WriteSeconds { get; set; }
        public double ThrottleSeconds { get; set; }
        public double MaxReadSeconds { get; set; }
        public double MaxWriteSeconds { get; set; }
        public long ReadOperations { get; set; }
        public long WriteOperations { get; set; }
        public int ChunkSize { get; set; }
        public int DelayMs { get; set; }
        public bool Done { get; set; }
    }

    // Two reusable buffers overlap source reads with destination writes. PowerShell
    // only polls snapshots: blocked I/O never blocks the reporting loop.
    public sealed class CopyWorker {
        readonly object gate = new object();
        readonly Stopwatch clock = Stopwatch.StartNew();
        readonly CancellationTokenSource cancel = new CancellationTokenSource();
        string phase = "starting", error;
        double phaseStart, activeStart = -1, lastProgress, readStart = -1, writeStart = -1;
        double readSeconds, writeSeconds, throttleSeconds, maxRead, maxWrite;
        long bytes, reads, writes;
        int chunkSize, delayMs;
        bool done;
        Task task;

        public void SetControls(int chunk, int delay) {
            if (chunk < 1 || chunk > 64 * 1024 * 1024 || delay < 0 || delay > 60000)
                throw new ArgumentOutOfRangeException("Copy controls are outside supported limits");
            lock (gate) { chunkSize = chunk; delayMs = delay; }
        }
        public void Cancel() { cancel.Cancel(); }
        void Phase(string value) { lock (gate) { phase = value; phaseStart = clock.Elapsed.TotalSeconds; } }
        public CopySnapshot Snapshot() {
            lock (gate) {
                double now = clock.Elapsed.TotalSeconds;
                return new CopySnapshot {
                    Phase = phase, Error = error, Bytes = bytes, Done = done,
                    ElapsedSeconds = now, ActiveSeconds = activeStart < 0 ? 0 : now - activeStart,
                    PhaseSeconds = now - phaseStart, IdleSeconds = now - lastProgress,
                    ReadPendingSeconds = readStart < 0 ? 0 : now - readStart,
                    WritePendingSeconds = writeStart < 0 ? 0 : now - writeStart,
                    ReadSeconds = readSeconds, WriteSeconds = writeSeconds,
                    ThrottleSeconds = throttleSeconds, MaxReadSeconds = maxRead,
                    MaxWriteSeconds = maxWrite, ReadOperations = reads, WriteOperations = writes,
                    ChunkSize = chunkSize, DelayMs = delayMs
                };
            }
        }
        public void Start(string source, string destination, long expected, int chunk, int delay, int concurrency) {
            if (task != null) throw new InvalidOperationException("Worker already started");
            if (concurrency < 1 || concurrency > 16) throw new ArgumentOutOfRangeException("concurrency");
            SetControls(chunk, delay);
            task = Task.Run(() => {
                Mutex[] slots = new Mutex[concurrency];
                int acquired = -1;
                try {
                    string root = Path.GetPathRoot(Path.GetFullPath(destination)).ToUpperInvariant();
                    string key;
                    using (var hash = SHA256.Create()) {
                        key = BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(root))).Replace("-", "");
                    }
                    for (int i = 0; i < slots.Length; i++)
                        slots[i] = new Mutex(false, "Local\\Filedarr-copy-" + key + "-" + i);
                    Phase("queued");
                    while (acquired < 0) {
                        cancel.Token.ThrowIfCancellationRequested();
                        try {
                            int slot = WaitHandle.WaitAny(slots, 250);
                            if (slot != WaitHandle.WaitTimeout) acquired = slot;
                        } catch (AbandonedMutexException ex) { acquired = ex.MutexIndex; }
                    }
                    lock (gate) { activeStart = lastProgress = clock.Elapsed.TotalSeconds; }
                    Phase("opening_source");
                    using (var input = new FileStream(source, FileMode.Open, FileAccess.Read, FileShare.Read,
                                                     65536, FileOptions.Asynchronous | FileOptions.SequentialScan)) {
                        if (input.Length != expected) throw new IOException("Source size changed before copying");
                        Phase("opening_destination");
                        using (var output = new FileStream(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None,
                                                          65536, FileOptions.Asynchronous | FileOptions.SequentialScan)) {
                            Copy(input, output, expected).GetAwaiter().GetResult();
                            Phase("flushing");
                            output.Flush(true);
                            if (output.Length != expected || input.Length != expected)
                                throw new IOException("Copy size verification failed");
                        }
                    }
                    Phase("copied");
                } catch (Exception ex) {
                    lock (gate) { error = ex.Message; }
                    Phase("failed");
                } finally {
                    // This synchronous outer worker owns and releases the mutex on
                    // the same thread, even though the I/O pipeline uses async tasks.
                    if (acquired >= 0) slots[acquired].ReleaseMutex();
                    foreach (var slot in slots) if (slot != null) slot.Dispose();
                    lock (gate) { done = true; }
                }
            });
        }

        // Stream overload also permits testing actual stalls and I/O failures.
        // The caller owns these streams; file-path copying above owns its handles.
        public void StartStreams(Stream input, Stream output, long expected, int chunk, int delay) {
            if (task != null) throw new InvalidOperationException("Worker already started");
            SetControls(chunk, delay);
            task = Task.Run(async () => {
                try {
                    lock (gate) { activeStart = lastProgress = clock.Elapsed.TotalSeconds; }
                    await Copy(input, output, expected).ConfigureAwait(false);
                    Phase("flushing");
                    await output.FlushAsync(cancel.Token).ConfigureAwait(false);
                    Phase("copied");
                } catch (Exception ex) {
                    lock (gate) { error = ex.Message; }
                    Phase("failed");
                } finally { lock (gate) { done = true; } }
            });
        }
        async Task<int> Read(Stream stream, byte[] buffer, int size) {
            double start = clock.Elapsed.TotalSeconds;
            lock (gate) { readStart = start; }
            try { return await stream.ReadAsync(buffer, 0, size, cancel.Token).ConfigureAwait(false); }
            finally {
                lock (gate) {
                    double elapsed = clock.Elapsed.TotalSeconds - start;
                    readSeconds += elapsed; maxRead = Math.Max(maxRead, elapsed); reads++; readStart = -1;
                }
            }
        }
        async Task Write(Stream stream, byte[] buffer, int count) {
            double start = clock.Elapsed.TotalSeconds;
            lock (gate) { writeStart = start; }
            try {
                await stream.WriteAsync(buffer, 0, count, cancel.Token).ConfigureAwait(false);
                lock (gate) { bytes += count; lastProgress = clock.Elapsed.TotalSeconds; }
            } finally {
                lock (gate) {
                    double elapsed = clock.Elapsed.TotalSeconds - start;
                    writeSeconds += elapsed; maxWrite = Math.Max(maxWrite, elapsed); writes++; writeStart = -1;
                }
            }
        }
        async Task Copy(Stream input, Stream output, long expected) {
            Phase("copying");
            int size;
            lock (gate) { size = chunkSize; }
            byte[] current = new byte[size], next = new byte[size];
            int count = await Read(input, current, size).ConfigureAwait(false);
            while (count > 0) {
                cancel.Token.ThrowIfCancellationRequested();
                int delay;
                lock (gate) { size = chunkSize; delay = delayMs; }
                if (next.Length != size) next = new byte[size];
                // Both tasks are observed before disposing streams, including failures.
                Task writing = Write(output, current, count);
                Task<int> reading = Read(input, next, size);
                await Task.WhenAll(writing, reading).ConfigureAwait(false);
                if (delay > 0) {
                    Phase("throttling");
                    double start = clock.Elapsed.TotalSeconds;
                    await Task.Delay(delay, cancel.Token).ConfigureAwait(false);
                    lock (gate) { throttleSeconds += clock.Elapsed.TotalSeconds - start; }
                    Phase("copying");
                }
                count = reading.Result;
                byte[] swap = current; current = next; next = swap;
            }
            lock (gate) { if (bytes != expected) throw new IOException("Copy size verification failed"); }
        }
    }
}
