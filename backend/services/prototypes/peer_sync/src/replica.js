// One device's complete copy of the trip.

import { vvGet, materialize, conflicts } from './crdt.js';

export class Replica {
  constructor(id) {
    this.id = id;
    this.ops = [];
    this.ids = new Set();
    this.vv = {};
    this.lamport = 0;
    this.seq = 0;
  }

  commit(fields) {
    const counter = vvGet(this.vv, this.id) + 1;
    const op = {
      id: `${this.id}:${counter}`,
      replica: this.id,
      counter,
      lamport: this.lamport + 1,
      deps: { ...this.vv },
      ...fields,
    };
    this.ingest([op]);
    return op;
  }

  ingest(incoming) {
    const fresh = incoming.filter(o => !this.ids.has(o.id));
    for (const op of fresh.sort((a, b) => a.lamport - b.lamport)) {
      this.ops.push(op);
      this.ids.add(op.id);
      if (op.counter > vvGet(this.vv, op.replica)) this.vv[op.replica] = op.counter;
      if (op.lamport > this.lamport) this.lamport = op.lamport;
    }
    return fresh;
  }

  // everything this replica knows that a peer summarised by `vv` does not
  since(vv) {
    return this.ops.filter(o => o.counter > vvGet(vv, o.replica));
  }

  add(time, place, title) { return this.commit({ type: 'add', actId: `${this.id.slice(0, 2)}${++this.seq}`, time, place, title }); }
  set(actId, field, value) { return this.commit({ type: 'set', actId, field, value }); }
  remove(actId) { return this.commit({ type: 'remove', actId }); }
  resolve(actId, choice) { return this.commit({ type: 'resolve', actId, choice }); }

  state() { return [...materialize(this.ops).values()]; }
  conflicts() { return conflicts(this.ops); }
}

// In-memory stand-in for a radio meeting, used by the tests.
export function sync(a, b) {
  const toB = a.since(b.vv);
  const toA = b.since(a.vv);
  b.ingest(toB);
  a.ingest(toA);
  return toA.length + toB.length;
}
