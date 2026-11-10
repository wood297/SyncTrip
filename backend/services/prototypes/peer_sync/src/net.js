// Peer discovery and anti-entropy over the local network. No server and no
// broker: devices announce themselves on a multicast group and then talk
// straight to each other over TCP.

import dgram from 'node:dgram';
import net from 'node:net';
import os from 'node:os';

const GROUP = '239.255.42.99';
const PORT = 41234;
const BEAT = 1500;

const send = (sock, msg) => { try { sock.write(JSON.stringify(msg) + '\n'); } catch {} };

// Loopback covers several devices simulated on one machine; the other
// addresses cover real devices on the same Wi-Fi.
function interfaces() {
  const out = ['127.0.0.1'];
  for (const list of Object.values(os.networkInterfaces())) {
    for (const i of list || []) {
      if (i.family === 'IPv4' && !i.internal) out.push(i.address);
    }
  }
  return out;
}

export class Link {
  constructor(replica, onChange) {
    this.r = replica;
    this.onChange = onChange;
    this.conns = new Map();
    this.dialing = new Set();
    this.senders = [];
    this.online = false;

    this.server = net.createServer(s => this.attach(s));
    this.server.listen(0, () => {
      this.port = this.server.address().port;
      this.listen();
      for (const addr of interfaces()) this.sender(addr);
      this.online = true;
      this.timer = setInterval(() => this.announce(), BEAT);
    });
  }

  listen() {
    const rx = dgram.createSocket({ type: 'udp4', reuseAddr: true });
    rx.on('error', () => {});
    rx.on('message', (buf, rinfo) => this.heard(buf, rinfo));
    rx.bind(PORT, () => {
      for (const addr of interfaces()) {
        try { rx.addMembership(GROUP, addr); } catch {}
      }
    });
    this.rx = rx;
  }

  // one sender per interface, because the outgoing interface is a socket
  // setting and node sends asynchronously
  sender(addr) {
    const tx = dgram.createSocket({ type: 'udp4', reuseAddr: true });
    tx.on('error', () => {});
    tx.bind(0, () => {
      try {
        tx.setMulticastInterface(addr);
        tx.setMulticastLoopback(true);
        this.senders.push(tx);
        this.announce();
      } catch {}
    });
  }

  announce() {
    if (!this.online) return;
    const msg = Buffer.from(JSON.stringify({ id: this.r.id, port: this.port }));
    for (const tx of this.senders) tx.send(msg, PORT, GROUP, () => {});
  }

  heard(buf, rinfo) {
    if (!this.online) return;
    let m;
    try { m = JSON.parse(buf); } catch { return; }
    if (!m.id || m.id === this.r.id) return;
    if (this.conns.has(m.id) || this.dialing.has(m.id)) return;
    if (this.r.id >= m.id) return; // only the lower name dials, so we get one link

    this.dialing.add(m.id);
    const sock = net.connect(m.port, rinfo.address);
    sock.on('error', () => {});
    sock.on('close', () => this.dialing.delete(m.id));
    sock.on('connect', () => {
      this.dialing.delete(m.id);
      send(sock, { t: 'have', id: this.r.id, vv: this.r.vv });
    });
    this.attach(sock);
  }

  attach(sock) {
    let buf = '';
    let peer = null;
    sock.setNoDelay(true);

    sock.on('data', chunk => {
      if (!this.online) return sock.destroy();
      buf += chunk;
      let i;
      while ((i = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, i);
        buf = buf.slice(i + 1);
        let m;
        try { m = JSON.parse(line); } catch { continue; }

        if (m.t === 'have') {
          peer = m.id;
          this.conns.set(peer, sock);
          send(sock, { t: 'ops', ops: this.r.since(m.vv) });
          this.onChange();
        } else if (m.t === 'ops') {
          const fresh = this.r.ingest(m.ops);
          if (fresh.length) {
            this.relay(fresh, sock); // pass on whatever this peer just taught us
            this.onChange();
          }
        }
      }
    });

    const drop = () => {
      if (peer && this.conns.get(peer) === sock) {
        this.conns.delete(peer);
        this.onChange();
      }
    };
    sock.on('close', drop);
    sock.on('error', drop);

    if (!sock.connecting) send(sock, { t: 'have', id: this.r.id, vv: this.r.vv });
  }

  push(ops) {
    for (const s of this.conns.values()) send(s, { t: 'ops', ops });
  }

  relay(ops, from) {
    for (const s of this.conns.values()) if (s !== from) send(s, { t: 'ops', ops });
  }

  peers() { return [...this.conns.keys()].sort(); }

  setOnline(v) {
    this.online = v;
    if (!v) {
      for (const s of this.conns.values()) s.destroy();
      this.conns.clear();
      this.dialing.clear();
    } else {
      this.announce();
    }
  }
}
