// Version vectors, causal comparison, state materialization, conflict detection.

export const vvGet = (vv, replica) => vv[replica] || 0;

// did a replica holding `vv` already have `op` when `vv` was taken?
export const saw = (vv, op) => vvGet(vv, op.replica) >= op.counter;

// neither op knew about the other, so they were made independently
export const concurrent = (a, b) => !saw(a.deps, b) && !saw(b.deps, a);

const order = (a, b) =>
  a.lamport - b.lamport || (a.replica < b.replica ? -1 : a.replica > b.replica ? 1 : 0);

export function materialize(ops) {
  const acts = new Map();
  for (const op of [...ops].sort(order)) {
    if (op.type === 'add') {
      acts.set(op.actId, {
        id: op.actId, title: op.title, place: op.place, time: op.time, dropped: false,
      });
      continue;
    }
    const a = acts.get(op.actId);
    if (!a) continue;
    if (op.type === 'set') a[op.field] = op.value;
    else if (op.type === 'remove') a.dropped = true;
    else if (op.type === 'resolve') a.dropped = op.choice === 'drop';
  }
  return acts;
}

// A pair of concurrent ops that merge fine arithmetically but mean two
// incompatible things for the group.
function disagree(a, b, acts) {
  if (a.type === 'set' && b.type === 'set' && a.actId === b.actId
      && a.field === b.field && a.value !== b.value) {
    // sorted so both devices word the same disagreement identically
    const [x, y] = [a.value, b.value].sort();
    return { actId: a.actId, reason: `two values for ${a.field}: "${x}" vs "${y}"` };
  }
  const rem = a.type === 'remove' ? a : b.type === 'remove' ? b : null;
  if (!rem) return null;
  const other = rem === a ? b : a;
  if (other.type === 'set' && other.actId === rem.actId) {
    return { actId: rem.actId, reason: `dropped by one member while another changed its ${other.field}` };
  }
  const stop = acts.get(rem.actId);
  if (other.type === 'add' && stop && other.place === stop.place) {
    return { actId: rem.actId, reason: `dropped by one member while another planned "${other.title}" at ${stop.place}` };
  }
  return null;
}

// Someone who had seen both sides and then acted on that activity has made
// the call for the group, so the disagreement is settled.
const settled = (ops, actId, a, b) => ops.some(r =>
  r !== a && r !== b && r.actId === actId && r.type !== 'add'
  && saw(r.deps, a) && saw(r.deps, b));

export function conflicts(ops) {
  const acts = materialize(ops);
  const out = [];
  const seen = new Set();
  for (let i = 0; i < ops.length; i++) {
    for (let j = i + 1; j < ops.length; j++) {
      const a = ops[i], b = ops[j];
      if (!concurrent(a, b)) continue;
      const d = disagree(a, b, acts);
      if (!d || settled(ops, d.actId, a, b)) continue;
      const key = `${d.actId}|${d.reason}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({ ...d, ops: [a.id, b.id].sort() });
    }
  }
  return out.sort((p, q) => (p.actId + p.reason).localeCompare(q.actId + q.reason));
}
