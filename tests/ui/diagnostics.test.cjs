const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
class Element {
  constructor(tag) {
    this.tag = tag; this.children = []; this.textContent = ''; this.className = '';
    this.classList = { toggle: (name, enabled) => { this[name] = enabled; } };
  }
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children = children; }
  querySelector(selector) {
    const name = selector.slice(1);
    for (const child of this.children) {
      if (child.className.split(' ').includes(name)) return child;
      const nested = child.querySelector(selector);
      if (nested) return nested;
    }
    return null;
  }
}
const root = new Element('div');
const transfer = new Element('div'); transfer.className = 'transfer'; root.append(transfer);
for (const name of ['speed', 'eta']) { const node = new Element('span'); node.className = name; transfer.append(node); }
let now = 0;
const context = { Date: { now: () => now }, setInterval: () => {}, document: {
  createElement: tag => new Element(tag), querySelectorAll: () => [root]
} };
context.window = context;
vm.createContext(context);
vm.runInContext(fs.readFileSync('static/diagnostics.js', 'utf8'), context);
const panel = context.TransferDiagnostics;
const data = { status: 'incomplete', diagnostics: {
  phase: 'copying', summary: 'Stalled: waiting for source read', read_pending_sec: 12,
  network: [{name: 'Direct Ethernet', type: 'Ethernet', link_mbps: 100, errors_delta: 2}]
} };
panel.update(root, data);
assert.match(root.querySelector('.transfer-health').textContent, /source read/);
let paragraphs = root.querySelector('.diagnostics-body').children.map(p => p.textContent).join('\n');
assert.match(paragraphs, /negotiated link is 100 Mbps/);
assert.match(paragraphs, /new packet errors/);
const details = root.querySelector('.live-diagnostics'); details.open = true;
now = 11000;
panel.refresh(root);
assert.match(root.querySelector('.transfer-health').textContent, /No importer heartbeat/);
assert.equal(root.querySelector('.speed').textContent, 'Unknown');
assert.equal(root.querySelector('.eta').textContent, 'ETA unknown');
panel.update(root, data);
assert.equal(root.querySelector('.live-diagnostics'), details);
assert.equal(details.open, true);
assert.match(root.querySelector('.transfer-health').textContent, /source read/);
panel.update(root, {status:'failed', diagnostics:{phase:'failed', summary:'<script>untrusted error</script>'}});
assert.equal(root.querySelector('.transfer-health').textContent, '<script>untrusted error</script>');
now = 50000;
panel.refresh(root);
assert.doesNotMatch(root.querySelector('.transfer-health').textContent, /No importer heartbeat/);
panel.update(root, {status:'incomplete'});
assert.match(root.querySelector('.diagnostics-body').children[0].textContent, /updated importer/);
console.log('Diagnostics UI checks passed: I/O waits, network warnings, missing heartbeats, recovery, preserved expansion, terminal failures and older importers.');
