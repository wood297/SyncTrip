import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { openReplica, saveSnapshot } from '../src/storage.js';
import { Replica, sync } from '../src/replica.js';

function fixture(t) {
  const dir = fs.mkdtempSync(path.join(process.env.TRIP_SYNC_TEST_DIR || os.tmpdir(), 'trip-sync-test-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return name => path.join(dir, `${name}.json`);
}

test('restart restores offline edits, clocks and unique activity IDs', t => {
  const file = fixture(t)('alice');
  const a = openReplica('alice', file);
  const stop = a.add('09:00', 'Indy', 'Museum');
  a.set(stop.actId, 'time', '10:30');
  const restored = openReplica('alice', file);
  assert.deepEqual(restored.state(), a.state());
  assert.deepEqual(restored.vv, a.vv);
  assert.equal(restored.lamport, a.lamport);
  const next = restored.add('12:00', 'Canal', 'Walk');
  assert.equal(next.counter, 3);
  assert.notEqual(next.actId, stop.actId);
  assert.equal(openReplica('alice', file).state().length, 2);
});

test('replica names with the same prefix produce separate activities', () => {
  const a = new Replica('alice'), b = new Replica('alex');
  a.add('09:00', 'Indy', 'Museum');
  b.add('12:00', 'Canal', 'Walk');
  sync(a, b);
  assert.equal(a.state().length, 2);
  assert.deepEqual(a.state(), b.state());
});

test('remote edits and unresolved conflicts survive restart and resolve after sync', t => {
  const file = fixture(t);
  let a = openReplica('alice', file('alice'));
  let b = openReplica('bob', file('bob'));
  const stop = a.add('09:00', 'Indy', 'Museum');
  sync(a, b);
  a.set(stop.actId, 'time', '10:00');
  b.set(stop.actId, 'time', '11:00');
  sync(a, b);
  const conflict = a.conflicts();
  assert.equal(conflict.length, 1);
  a = openReplica('alice', file('alice'));
  b = openReplica('bob', file('bob'));
  assert.deepEqual(a.conflicts(), conflict);
  assert.deepEqual(b.conflicts(), conflict);
  assert.equal(sync(a, b), 0);
  a.set(stop.actId, 'time', '10:30');
  assert.equal(sync(a, b), 1);
  assert.deepEqual(a.state(), b.state());
  assert.equal(openReplica('bob', file('bob')).conflicts().length, 0);
});

test('missing file starts empty; malformed or incompatible files are preserved', t => {
  const file = fixture(t)('alice');
  assert.equal(openReplica('alice', file).ops.length, 0);
  for (const raw of ['{broken', JSON.stringify({ version: 2, replicaId: 'alice', ops: [] }),
    JSON.stringify({ version: 1, replicaId: 'bob', ops: [] })]) {
    fs.writeFileSync(file, raw);
    assert.throws(() => openReplica('alice', file), /Cannot load/);
    assert.equal(fs.readFileSync(file, 'utf8'), raw);
  }
});

test('failed persistence does not accept the edit in memory', t => {
  const file = fixture(t)('blocked');
  fs.mkdirSync(file);
  const a = new Replica('alice');
  a.beforeIngest = ops => saveSnapshot(file, a.id, ops);
  assert.throws(() => a.add('09:00', 'Indy', 'Museum'));
  assert.equal(a.ops.length, 0);
  assert.deepEqual(a.vv, {});
  assert.equal(a.lamport, 0);
  assert.deepEqual(fs.readdirSync(path.dirname(file)), ['blocked.json']);
});

test('duplicate operations and missing causal history are rejected', t => {
  const file = fixture(t)('alice');
  const a = new Replica('alice');
  const first = a.add('09:00', 'Indy', 'Museum');
  const second = a.set(first.actId, 'time', '10:00');
  assert.throws(() => saveSnapshot(file, a.id, [first, first]), /Duplicate/);
  assert.throws(() => saveSnapshot(file, a.id, [second]), /gap/);
  assert.equal(fs.existsSync(file), false);
});
