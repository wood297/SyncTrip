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
test/              the test suite
```

## Run and save a trip

Requires a current Node.js installation; no third-party packages are needed.

```powershell
node --test test/*.test.js
node src/cli.js alice
```

The CLI automatically saves local edits and received peer edits in `data/`.
Restart with the same name from the same working directory to restore the trip,
including unresolved conflicts and the operation history needed for later sync.
Each name has its own file. For an explicit location:

```powershell
node src/cli.js alice ./data/alice-demo.json
```

Try `offline`, `add 09:00 Indy Museum visit`, `show`, and `quit`. Run the same
launch command again: the activity and operation count should be restored.
Activity IDs are printed in the timeline; use those IDs in `set`, `rm`, or
`resolve` commands. New activity IDs use the full replica name and operation
counter, preventing prefix collisions and reuse after restart. Existing saved
activity IDs remain usable.

Snapshots contain a format version, replica identity and operations. Loading
rebuilds the version vector, clock and materialized trip. Invalid JSON, unknown
versions, mismatched identities and incomplete operation histories stop startup
with an error and leave the original file unchanged. Writes use a unique
temporary file, flush it, then rename it over the snapshot. A failed write
rejects the edit before changing memory or broadcasting it.

Use one running process per replica identity and snapshot file. This prototype
does not implement file locking, encryption, backups, or operation-log compaction.
Rename-based replacement reduces partial-write risk but is not a guarantee
against every filesystem or power-loss failure. Networking remains the original
LAN prototype; persistence tests simulate peer exchange in memory.
