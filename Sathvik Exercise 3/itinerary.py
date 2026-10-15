import json
from pathlib import Path
from uuid import uuid4

from crdt import GrowOnlySet, Register


# One device's local copy of the trip.
class Itinerary:
    # Start with a unique device ID, a logical clock, and empty trip data.
    def __init__(self, replica_id: str):
        if not replica_id:
            raise ValueError("A unique, nonempty replica ID is required")
        self.replica_id = replica_id
        self.clock = 0
        self.activities: dict[str, dict[str, Register]] = {}
        self.votes: dict[str, dict[str, Register]] = {}
        self.conflicts: dict[str, dict[str, dict]] = {}
        self.proposed = GrowOnlySet()
        self.decisions: dict[str, Register] = {}
        self.deleted = GrowOnlySet()

    # Advance the clock and attach a new timestamp to this value.
    def _write(self, value: str, base: tuple[int, str] | None = None) -> Register:
        self.clock += 1
        return Register(value, (self.clock, self.replica_id), base)

    # Name a proposed value by its write stamp, such as "4:Bob".
    @staticmethod
    def _key(register: Register) -> str:
        return f"{register.stamp[0]}:{register.stamp[1]}"

    # Two edits conflict when both replaced the same value with different values.
    @staticmethod
    def _concurrent(a: Register, b: Register) -> bool:
        return (a.base is not None and a.base == b.base
                and a.stamp != b.stamp and a.value != b.value)

    # Find the field's vote, creating an empty record if needed.
    def _conflict(self, activity_id: str, field: str) -> dict:
        return self.conflicts.setdefault(activity_id, {}).setdefault(
            field, {"candidates": {}, "votes": {}, "result": None})

    # Return a field's vote only while it is still open.
    def _open_conflict(self, activity_id: str, field: str) -> dict:
        self._require_visible(activity_id)
        conflict = self.conflicts.get(activity_id, {}).get(field)
        if conflict is None or conflict["result"] is not None:
            raise KeyError(f"No open vote on this activity's {field}")
        return conflict

    # Check field names and HH:MM times. Notes may be empty.
    @staticmethod
    def _validate(field: str, value: str) -> None:
        if field not in ("title", "time", "notes"):
            raise ValueError("Only title, time, and notes can be edited")
        if not isinstance(value, str) or (field != "notes" and not value.strip()):
            raise ValueError("Values must be nonempty strings")
        if field == "time":
            parts = value.split(":")
            if (len(parts) != 2 or any(len(p) != 2 or not p.isdecimal() for p in parts)
                    or not 0 <= int(parts[0]) <= 23 or not 0 <= int(parts[1]) <= 59):
                raise ValueError("Use a 24-hour time such as 09:30")

    # A proposal that was voted down is hidden like a deleted activity.
    def _rejected(self, activity_id: str) -> bool:
        decision = self.decisions.get(activity_id)
        return decision is not None and decision.value == "rejected"

    # A proposal stays pending until its vote is closed.
    def _pending(self, activity_id: str) -> bool:
        return activity_id in self.proposed.members and activity_id not in self.decisions

    # Reject local actions on missing, deleted, or rejected activities.
    def _require_visible(self, activity_id: str) -> None:
        if (activity_id not in self.activities or activity_id in self.deleted.members
                or self._rejected(activity_id)):
            raise KeyError("Unknown or deleted activity")

    # Create a unique activity ID and separate registers for its fields.
    def add(self, title: str, time: str, notes: str = "") -> str:
        self._validate("title", title)
        self._validate("time", time)
        self._validate("notes", notes)
        activity_id = uuid4().hex
        self.activities[activity_id] = {
            "title": self._write(title), "time": self._write(time),
            "notes": self._write(notes)
        }
        self.votes[activity_id] = {}
        return activity_id

    # Suggest an activity that only joins the itinerary if the group votes it in.
    def propose(self, title: str, time: str, notes: str = "") -> str:
        activity_id = self.add(title, time, notes)
        self.proposed.add(activity_id)
        return activity_id

    # Close a proposal's vote: a positive net score adds it; zero or below rejects it.
    def decide(self, activity_id: str) -> str:
        self._require_visible(activity_id)
        if not self._pending(activity_id):
            raise KeyError("No open proposal for this activity")
        score = sum(1 if v.value == "up" else -1 for v in self.votes[activity_id].values())
        outcome = "added" if score > 0 else "rejected"
        self.decisions[activity_id] = self._write(outcome)
        return outcome

    # Update only the chosen field, leaving the other fields alone.
    def edit(self, activity_id: str, field: str, value: str) -> None:
        self._require_visible(activity_id)
        self._validate(field, value)
        conflict = self.conflicts.get(activity_id, {}).get(field)
        if conflict is not None and conflict["result"] is None:
            raise ValueError(f"A vote on this activity's {field} is still open")
        current = self.activities[activity_id][field]
        self.activities[activity_id][field] = self._write(value, current.stamp)

    # Store one current vote per traveler. Renaming keeps the same votes.
    def vote(self, activity_id: str, traveler: str, direction: str = "up") -> None:
        self._require_visible(activity_id)
        if not traveler.strip():
            raise ValueError("Traveler name is required")
        if direction not in ("up", "down"):
            raise ValueError("Vote direction must be up or down")
        self.votes[activity_id][traveler] = self._write(direction)

    # Choose one of the proposed values for a field in conflict. One current choice per traveler.
    def vote_field(self, activity_id: str, field: str, traveler: str, value: str) -> None:
        conflict = self._open_conflict(activity_id, field)
        if not traveler.strip():
            raise ValueError("Traveler name is required")
        matches = [reg for reg in conflict["candidates"].values() if reg.value == value]
        if not matches:
            raise ValueError(f"{value!r} is not one of the proposed values")
        choice = max(matches, key=lambda reg: reg.stamp)
        conflict["votes"][traveler] = self._write(self._key(choice))

    # Count the votes for each proposed value, in value order.
    def tally(self, activity_id: str, field: str) -> list[dict]:
        conflict = self.conflicts[activity_id][field]
        options = [{"key": key, "value": reg.value, "stamp": reg.stamp,
                    "votes": sorted(t for t, v in conflict["votes"].items() if v.value == key)}
                   for key, reg in conflict["candidates"].items()]
        return sorted(options, key=lambda option: (option["value"], option["stamp"]))

    # Close the vote: the most-voted value wins (newest edit breaks ties) and becomes the field.
    def resolve(self, activity_id: str, field: str) -> str:
        conflict = self._open_conflict(activity_id, field)
        if not conflict["votes"]:
            raise ValueError("Nobody has voted yet")
        winner = max(self.tally(activity_id, field),
                     key=lambda option: (len(option["votes"]), option["stamp"]))
        current = self.activities[activity_id][field]
        written = self._write(winner["value"], current.stamp)
        self.activities[activity_id][field] = written
        conflict["result"] = Register(winner["key"], written.stamp)
        return winner["value"]

    # Remember the deleted ID so older messages cannot bring it back.
    def delete(self, activity_id: str) -> None:
        self._require_visible(activity_id)
        self.deleted.add(activity_id)

    # Receive another copy: merge each field and vote, keep deletions, and advance the clock.
    def merge(self, other: "Itinerary") -> None:
        self.clock = max(self.clock, other.clock)
        for activity_id, fields in other.activities.items():
            local = self.activities.setdefault(activity_id, {})
            for name, incoming in fields.items():
                if name not in local:
                    local[name] = incoming
                    continue
                if self._concurrent(local[name], incoming):
                    candidates = self._conflict(activity_id, name)["candidates"]
                    for register in (local[name], incoming):
                        candidates[self._key(register)] = register
                local[name] = local[name].merge(incoming)
        for activity_id, voters in other.votes.items():
            local_votes = self.votes.setdefault(activity_id, {})
            for traveler, incoming in voters.items():
                local_votes[traveler] = (local_votes[traveler].merge(incoming)
                                         if traveler in local_votes else incoming)
        for activity_id, fields in other.conflicts.items():
            for name, incoming in fields.items():
                local = self._conflict(activity_id, name)
                local["candidates"].update(incoming["candidates"])
                for traveler, vote in incoming["votes"].items():
                    local["votes"][traveler] = (local["votes"][traveler].merge(vote)
                                                if traveler in local["votes"] else vote)
                results = [r for r in (local["result"], incoming["result"]) if r is not None]
                local["result"] = max(results, key=lambda r: r.stamp) if results else None
        self.proposed.merge(other.proposed)
        for activity_id, incoming in other.decisions.items():
            self.decisions[activity_id] = (self.decisions[activity_id].merge(incoming)
                                           if activity_id in self.decisions else incoming)
        self.deleted.merge(other.deleted)

    # Describe each field vote on an activity: its options, voters, and winner once closed.
    def _field_votes(self, activity_id: str) -> dict[str, dict]:
        summary = {}
        for name, conflict in sorted(self.conflicts.get(activity_id, {}).items()):
            result = conflict["result"]
            summary[name] = {
                "open": result is None,
                "winner": None if result is None else conflict["candidates"][result.value].value,
                "options": [{"value": o["value"], "score": len(o["votes"]), "voters": o["votes"]}
                            for o in self.tally(activity_id, name)],
            }
        return summary

    # Describe one activity with its up/down vote counts and any field votes.
    def _row(self, activity_id: str) -> dict:
        fields, votes = self.activities[activity_id], self.votes[activity_id].values()
        return {"id": activity_id, "title": fields["title"].value,
                "time": fields["time"].value,
                "notes": fields["notes"].value,
                "pending": self._pending(activity_id),
                "upvotes": sum(v.value == "up" for v in votes),
                "downvotes": sum(v.value == "down" for v in votes),
                "votes": sum(1 if v.value == "up" else -1 for v in votes),
                "field_votes": self._field_votes(activity_id)}

    # Show activities in time order, hide deletions and rejected proposals, and count up/down votes.
    # Pending proposals are included but marked. Field votes are kept separate from up/down votes.
    def rows(self) -> list[dict]:
        rows = [self._row(activity_id) for activity_id in self.activities
                if activity_id not in self.deleted.members and not self._rejected(activity_id)]
        return sorted(rows, key=lambda row: (row["time"], row["id"]))

    # List proposals that were voted down and kept off the itinerary.
    def rejected_rows(self) -> list[dict]:
        rows = [self._row(activity_id) for activity_id in self.activities
                if activity_id not in self.deleted.members and self._rejected(activity_id)]
        return sorted(rows, key=lambda row: (row["time"], row["id"]))

    # Convert a register to JSON, including the replaced stamp for edits.
    @staticmethod
    def _dump(reg: Register) -> dict:
        data = {"value": reg.value, "stamp": list(reg.stamp)}
        if reg.base is not None:
            data["base"] = list(reg.base)
        return data

    # Rebuild a register from JSON.
    @staticmethod
    def _restore(data: dict) -> Register:
        base = data.get("base")
        return Register(data["value"], tuple(data["stamp"]), tuple(base) if base else None)

    # Package shared data, including timestamps, field votes, proposals, and deletions, for saving or comparison.
    def payload(self) -> dict:
        dump = self._dump
        return {
            "activities": {
                aid: {name: dump(reg) for name, reg in sorted(fields.items())}
                for aid, fields in sorted(self.activities.items())
            },
            "votes": {aid: {traveler: dump(reg) for traveler, reg in sorted(voters.items())}
                      for aid, voters in sorted(self.votes.items())},
            "conflicts": {
                aid: {name: {"candidates": {k: dump(r) for k, r in sorted(c["candidates"].items())},
                             "votes": {t: dump(r) for t, r in sorted(c["votes"].items())},
                             "result": None if c["result"] is None else dump(c["result"])}
                      for name, c in sorted(fields.items())}
                for aid, fields in sorted(self.conflicts.items())
            },
            "proposed": sorted(self.proposed.members),
            "decisions": {aid: dump(reg) for aid, reg in sorted(self.decisions.items())},
            "deleted": sorted(self.deleted.members),
        }

    # Save the trip, device ID, and clock to JSON using a temporary file first.
    def save(self, path: str | Path) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        document = {"version": 3, "replica_id": self.replica_id,
                    "clock": self.clock, "payload": self.payload()}
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text(json.dumps(document, indent=2), encoding="utf-8")
        temporary.replace(path)

    # Restore a device from a trusted saved file, including its clock and registers.
    @classmethod
    def load(cls, path: str | Path) -> "Itinerary":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        if data["version"] not in (2, 3):
            raise ValueError("Unsupported snapshot version")
        replica = cls(data["replica_id"])
        replica.clock = data["clock"]
        payload = data["payload"]
        restore = cls._restore
        for aid, fields in payload["activities"].items():
            replica.activities[aid] = {name: restore(reg) for name, reg in fields.items()}
        replica.votes = {aid: {traveler: restore(reg) for traveler, reg in voters.items()}
                         for aid, voters in payload["votes"].items()}
        replica.conflicts = {
            aid: {name: {"candidates": {k: restore(r) for k, r in c["candidates"].items()},
                         "votes": {t: restore(r) for t, r in c["votes"].items()},
                         "result": None if c["result"] is None else restore(c["result"])}
                  for name, c in fields.items()}
            for aid, fields in payload.get("conflicts", {}).items()
        }
        replica.proposed = GrowOnlySet(set(payload.get("proposed", [])))
        replica.decisions = {aid: restore(reg)
                             for aid, reg in payload.get("decisions", {}).items()}
        replica.deleted = GrowOnlySet(set(payload["deleted"]))
        return replica
