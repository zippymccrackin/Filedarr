// All diagnosis text is inserted as text, including remote error messages and paths.
window.TransferDiagnostics = {
  update(root, data) {
    root._transferStatus = data;
    root._heartbeatAt = Date.now();
    let health = root.querySelector('.transfer-health');
    if (!health) {
      health = document.createElement('div');
      health.className = 'transfer-health';
      const details = document.createElement('details');
      details.className = 'live-diagnostics';
      const summary = document.createElement('summary');
      summary.textContent = 'Transfer diagnostics';
      const body = document.createElement('div');
      body.className = 'diagnostics-body';
      details.append(summary, body);
      root.querySelector('.transfer').append(health, details);
    }
    const d = data.diagnostics;
    const body = root.querySelector('.diagnostics-body');
    body.replaceChildren();
    const line = text => {
      const p = document.createElement('p');
      p.textContent = text;
      body.append(p);
    };
    if (!d) {
      line('Live I/O diagnostics require the updated importer and entire ps folder. Existing transfers retain their old worker until restarted.');
    } else {
      if (d.advice) line(d.advice);
      line(`Current source read wait: ${d.read_pending_sec ?? 0} s | Destination write wait: ${d.write_pending_sec ?? 0} s`);
      line(`Time since last completed write: ${d.idle_sec ?? 0} s | Current phase: ${d.phase} (${d.phase_sec ?? 0} s)`);
      line(`Total read operation time: ${d.read_sec ?? 0} s | Write operation time: ${d.write_sec ?? 0} s | Deliberate delay: ${d.throttle_sec ?? 0} s`);
      line(`Longest read: ${d.max_read_sec ?? 0} s | Longest write: ${d.max_write_sec ?? 0} s`);
      line('Read and write times overlap. They measure file API latency, including remote disk and network waits for shares; they do not identify a failing disk or cable by themselves.');
      if (d.throttle_limit_mb_s != null) line(`Configured throttle ceiling: ${d.throttle_limit_mb_s} MB/s before I/O overhead.`);
      if (data.elapsed_sec > 0) line(`Average since copying started: ${(data.transferred / 1048576 / data.elapsed_sec).toFixed(2)} MB/s. Main speed display uses recent samples.`);
      for (const adapter of d.network || []) {
        if (adapter.error) { line(adapter.name); continue; }
        line(`${adapter.name}: ${adapter.link_mbps} Mbps link | Receive ${adapter.receive_mb_s ?? 'measuring'} MB/s | Send ${adapter.send_mb_s ?? 'measuring'} MB/s | New errors ${adapter.errors_delta ?? 'measuring'} | Discards ${adapter.discards_delta ?? 'measuring'}`);
        if (adapter.link_mbps > 0 && adapter.link_mbps <= 100 && /ethernet/i.test(adapter.type))
          line(`Check ${adapter.name}: its negotiated link is ${adapter.link_mbps} Mbps. If your share uses this adapter, verify the cable and both PCs' negotiated speeds.`);
        if (adapter.errors_delta > 0 || adapter.discards_delta > 0)
          line(`Check ${adapter.name}: Windows recorded new packet errors/discards. Inspect the link, driver and congestion if this adapter carries the transfer.`);
      }
      if (d.network?.length) line('Adapter counters cover all traffic on this PC and refresh every five seconds. The app does not assume which adapter carries your share.');
    }
    this.refresh(root);
  },
  refresh(root) {
    const data = root._transferStatus;
    if (!data) return;
    const health = root.querySelector('.transfer-health');
    const missing = data.status === 'incomplete' && Date.now() - root._heartbeatAt > 10000;
    health.textContent = missing
      ? `No importer heartbeat for ${Math.floor((Date.now() - root._heartbeatAt) / 1000)} seconds. Check the importer process and its connection to the dashboard; current speed is unknown.`
      : data.diagnostics?.summary || (data.status === 'stale' ? 'Importer updates stopped. Current transfer state is unknown.' : 'Live I/O diagnostics unavailable for this transfer.');
    health.classList.toggle('diagnostic-warning', missing || /stalled|failed|queued/i.test(health.textContent));
    if (missing) {
      const speed = root.querySelector('.speed');
      const eta = root.querySelector('.eta');
      if (speed) speed.textContent = 'Unknown';
      if (eta) eta.textContent = 'ETA unknown';
    }
  }
};
setInterval(() => document.querySelectorAll('.transfer-container').forEach(root => TransferDiagnostics.refresh(root)), 1000);
