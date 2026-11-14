import test from 'node:test';
import assert from 'node:assert/strict';
import { Replica, sync } from '../../backend/services/prototypes/peer_sync/src/replica.js';

const snapshot = r => JSON.stringify(r.state().sort((a, b) => a.id.localeCompare(b.id)));

// deterministic rng so a failing seed can be replayed
const rng = seed => () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;

const gossipUntilQuiet = reps => {
  for (let round = 0; round < reps.length; round++) {
    for (const a of reps) for (const b of reps) if (a !== b) sync(a, b);
  }
};

test('replicas converge after random partitions and reconnections', () => {
  for (let seed = 1; seed <= 100; seed++) {
    const rand = rng(seed);
    const pick = arr => arr[Math.floor(rand() * arr.length)];
    const reps = ['a', 'b', 'c', 'd'].map(n => new Replica(n));
    const places = ['louvre', 'versailles', 'orsay', 'eiffel'];

    for (let step = 0; step < 80; step++) {
      const r = pick(reps);
      const acts = r.state();
      const roll = rand();
      if (roll < 0.4 || !acts.length) {
        r.add(`${10 + Math.floor(rand() * 9)}:00`, pick(places), `stop ${step}`);
      } else if (roll < 0.75) {
        r.set(pick(acts).id, 'time', `${10 + Math.floor(rand() * 9)}:00`);
      } else {
        r.remove(pick(acts).id);
      }
      if (rand() < 0.5) {
        const x = pick(reps), y = pick(reps);
        if (x !== y) sync(x, y);
      }
    }

    gossipUntilQuiet(reps);
    const want = snapshot(reps[0]);
    for (const r of reps) {
      assert.equal(snapshot(r), want, `seed ${seed}: ${r.id} diverged`);
      assert.equal(r.conflicts().length, reps[0].conflicts().length,
        `seed ${seed}: ${r.id} disagrees on conflicts`);
    }
  }
});

test('an edit reaches a peer that never met its author', () => {
  const [alice, bob, carol] = ['alice', 'bob', 'carol'].map(n => new Replica(n));
  const op = bob.add('09:00', 'orsay', 'Musee d Orsay');

  sync(alice, bob);            // alice and bob meet
  sync(alice, carol);          // carol only ever meets alice

  assert.ok(carol.ids.has(op.id), 'carol should have received bob\'s op through alice');
  assert.equal(snapshot(carol), snapshot(bob));
});

test('sync carries only what the peer is missing', () => {
  const a = new Replica('a'), b = new Replica('b');
  for (let i = 0; i < 20; i++) a.add('10:00', 'louvre', `stop ${i}`);

  assert.equal(sync(a, b), 20);
  assert.equal(sync(a, b), 0, 'a second meeting with no edits should transfer nothing');

  a.add('11:00', 'orsay', 'one more');
  assert.equal(sync(a, b), 1, 'only the new op should cross the wire');
});

test('a genuine disagreement is surfaced instead of silently applied', () => {
  const [alice, bob, carol] = ['alice', 'bob', 'carol'].map(n => new Replica(n));
  const stop = alice.add('14:00', 'versailles', 'Palace tour');
  sync(alice, bob);
  sync(alice, carol);

  // out of range of each other
  bob.remove(stop.actId);
  carol.add('18:00', 'versailles', 'Group dinner');

  sync(alice, bob);
  sync(alice, carol);
  gossipUntilQuiet([alice, bob, carol]);

  for (const r of [alice, bob, carol]) {
    const cf = r.conflicts();
    assert.equal(cf.length, 1, `${r.id} should see exactly one conflict`);
    assert.equal(cf[0].actId, stop.actId);
    assert.ok(r.state().find(a => a.id === stop.actId), 'the stop must not vanish');
  }

  alice.resolve(stop.actId, 'keep');
  gossipUntilQuiet([alice, bob, carol]);

  for (const r of [alice, bob, carol]) {
    assert.equal(r.conflicts().length, 0, `${r.id} should see the conflict settled`);
    assert.equal(r.state().find(a => a.id === stop.actId).dropped, false);
  }
});

test('concurrent edits to the same field are flagged, not overwritten quietly', () => {
  const a = new Replica('a'), b = new Replica('b');
  const stop = a.add('14:00', 'louvre', 'Museum');
  sync(a, b);

  a.set(stop.actId, 'time', '10:00');
  b.set(stop.actId, 'time', '16:00');
  sync(a, b);

  assert.equal(a.conflicts().length, 1);
  assert.equal(snapshot(a), snapshot(b));

  a.set(stop.actId, 'time', '12:00'); // re-editing after seeing both settles it
  sync(a, b);
  assert.equal(b.conflicts().length, 0);
  assert.equal(b.state()[0].time, '12:00');
});
