// Versioned operation-history persistence. Derived state is rebuilt on load.
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { Replica } from './replica.js';

const object = v => v !== null && typeof v === 'object' && !Array.isArray(v);
const text = v => typeof v === 'string' && v.length > 0;
const positive = v => Number.isSafeInteger(v) && v > 0;
const fields = ['time', 'place', 'title'];

export function validateSnapshot(data, expectedId) {
  if (!object(data) || data.version !== 1) throw new Error('Unsupported snapshot version (expected 1)');
  if (!text(data.replicaId) || data.replicaId !== expectedId) throw new Error('Snapshot replica identity does not match the requested name');
  if (!Array.isArray(data.ops)) throw new Error('Snapshot operations must be an array');
  const ids = new Set();
  const counters = new Map();
  for (const op of data.ops) {
    if (!object(op) || !text(op.replica) || !positive(op.counter)
        || op.id !== `${op.replica}:${op.counter}` || !positive(op.lamport)
        || !text(op.actId) || !object(op.deps)) throw new Error('Invalid operation metadata');
    if (ids.has(op.id)) throw new Error(`Duplicate operation: ${op.id}`);
    ids.add(op.id);
    for (const [id, count] of Object.entries(op.deps)) {
      if (!text(id) || !Number.isSafeInteger(count) || count < 0) throw new Error('Invalid version vector');
    }
    if ((op.deps[op.replica] || 0) !== op.counter - 1) throw new Error('Invalid author dependency');
    if (op.type === 'add') {
      if (!fields.every(f => text(op[f]))) throw new Error('Activity requires time, place and title');
    } else if (op.type === 'set') {
      if (!fields.includes(op.field) || !text(op.value)) throw new Error('Invalid activity field or value');
    } else if (op.type === 'resolve') {
      if (!['keep', 'drop'].includes(op.choice)) throw new Error('Resolution must be keep or drop');
    } else if (op.type !== 'remove') throw new Error('Unknown operation type');
    if (!counters.has(op.replica)) counters.set(op.replica, new Set());
    counters.get(op.replica).add(op.counter);
  }
  // Version vectors summarize contiguous history, not merely the highest ID.
  for (const counts of counters.values()) {
    for (const count of counts) {
      if (count > counts.size) throw new Error('Snapshot has a gap in operation history');
    }
  }
  for (const op of data.ops) {
    for (const [id, count] of Object.entries(op.deps)) {
      if (count > (counters.get(id)?.size || 0)) throw new Error('Snapshot is missing a causal dependency');
    }
  }
  return data;
}

export function saveSnapshot(file, replicaId, ops) {
  const data = validateSnapshot({ version: 1, replicaId, ops }, replicaId);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temporary = `${file}.${randomUUID()}.tmp`;
  let fd;
  try {
    fd = fs.openSync(temporary, 'wx');
    fs.writeFileSync(fd, JSON.stringify(data, null, 2) + '\n');
    fs.fsyncSync(fd);
    fs.closeSync(fd);
    fd = undefined;
    fs.renameSync(temporary, file);
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
    if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
  }
}

export function openReplica(id, file) {
  const replica = new Replica(id);
  let raw;
  try { raw = fs.readFileSync(file, 'utf8'); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (raw !== undefined) {
    try {
      const data = validateSnapshot(JSON.parse(raw), id);
      replica.ingest(data.ops);
    } catch (error) {
      throw new Error(`Cannot load ${file}: ${error.message}. Existing file was left unchanged.`, { cause: error });
    }
  }
  replica.beforeIngest = ops => saveSnapshot(file, id, ops);
  return replica;
}
