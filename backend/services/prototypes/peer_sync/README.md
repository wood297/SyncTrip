# trip-sync

Offline-first peer-to-peer sync for a shared travel plan.

Every device keeps a complete copy of the trip and stays fully editable with no network. When two
devices come into range they exchange everything each has learned since they last met, including
edits that started on a third device neither has seen. Edits that merge cleanly are applied
automatically. Genuine disagreements are surfaced for the group to settle instead of being
silently overwritten.

There is no server, no broker and no cloud account. Devices find each other on the local network
and talk directly.

## Layout

```
src/crdt.js        causality, state fold, conflict detection
src/replica.js     one device's copy of the trip
src/net.js         peer discovery and sync over the local network
src/cli.js         one device, one terminal
../../../../tests/sync/   the test suite (run npm test from this directory or repo root)
```
