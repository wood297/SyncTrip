from pathlib import Path
from itinerary import Itinerary


# Run the offline trip scenarios and save their results.
def main():
    output = []

    # Print a message and keep a copy for the evidence file.
    def report(message):
        print(message)
        output.append(message)

    # Display each device's schedule, notes, and vote totals.
    # A field vote is listed under its activity, apart from that activity's up/down votes.
    def show(label, replicas):
        report("\n" + label)
        for replica in replicas:
            report(f"  {replica.replica_id}")
            for row in replica.rows():
                time_vote = row["field_votes"].get("time")
                time = "--:--" if time_vote and time_vote["open"] else row["time"]
                pending = "  [PROPOSED: not on itinerary until vote closes]" if row["pending"] else ""
                report(f"    {time} | {row['title']:<14} | "
                       f"up={row['upvotes']} down={row['downvotes']} score={row['votes']:+d}"
                       f"{pending}")
                if row["notes"]:
                    report(f"      Notes: {row['notes']}")
                for field, vote in row["field_votes"].items():
                    status = "OPEN" if vote["open"] else f"CLOSED, {vote['winner']} wins"
                    report(f"      {field.capitalize()} vote for this {row['title']} "
                           f"(choosing between proposed {field}s) [{status}]:")
                    for option in vote["options"]:
                        voters = ", ".join(option["voters"]) or "no votes"
                        report(f"        {option['value']}  score={option['score']:+d}  ({voters})")
            for row in replica.rejected_rows():
                report(f"    Not added: {row['time']} {row['title']} "
                       f"(up={row['upvotes']} down={row['downvotes']} score={row['votes']:+d})")

    # Save every device's copy for one stage of a scenario.
    def save_all(replicas, folder, stage):
        for replica in replicas:
            replica.save(folder / f"{replica.replica_id}_{stage}.json")

    # Share every device's changes with every other device, then check agreement.
    def sync(replicas):
        for replica in replicas:
            for other in replicas:
                if other is not replica:
                    replica.merge(other)
        assert all(r.payload() == replicas[0].payload() for r in replicas)

    # Save offline copies, simulate a restart and repeated/old messages, then check agreement.
    def reconnect(replicas, folder, stage="synced"):
        save_all(replicas, folder, "offline")
        alice, bob, charlie = replicas
        bob = Itinerary.load(folder / "Bob_offline.json")
        stale_bob = Itinerary.load(folder / "Bob_offline.json")
        alice.merge(bob)
        alice.merge(bob)
        charlie.merge(alice)
        bob.merge(charlie)
        alice.merge(bob)
        charlie.merge(stale_bob)
        replicas = [alice, bob, charlie]
        assert alice.payload() == bob.payload() == charlie.payload()
        save_all(replicas, folder, stage)
        return replicas

    # Create three independent devices for a fresh scenario.
    def new_group():
        return [Itinerary(name) for name in ("Alice", "Bob", "Charlie")]

    report("SCENARIO 1: DINNER EDITS, NIGHT WALK, AND MUSEUM DELETION")
    alice, bob, charlie = new_group()
    dinner = alice.add("Dinner", "19:00")
    museum = alice.add("Museum Tour", "16:00")
    bob.merge(alice)
    charlie.merge(alice)
    show("SHARED START", [alice, bob, charlie])
    alice.edit(dinner, "time", "19:30")
    bob.edit(dinner, "notes", "Vegetarian options available")
    walk = charlie.add("Night Walk", "21:00")
    alice.delete(museum)
    show("OFFLINE COPIES", [alice, bob, charlie])
    replicas = reconnect([alice, bob, charlie], Path("evidence/scenario_1"))
    show("RECONNECTED: ALL COPIES AGREE", replicas)
    final = {row["id"]: row for row in replicas[0].rows()}
    assert final[dinner]["time"] == "19:30"
    assert final[dinner]["notes"] == "Vegetarian options available"
    assert final[walk]["title"] == "Night Walk"
    assert museum not in final
    report("PASS: Dinner at 7:30 PM keeps Bob's notes; Night Walk survives; Museum Tour stays deleted.")

    report("\nSCENARIO 2: LUNCH BECOMES TACO BELL WITH UPVOTES AND DOWNVOTES")
    alice, bob, charlie = new_group()
    lunch = alice.add("Lunch", "12:00")
    bob.merge(alice)
    charlie.merge(alice)
    show("SHARED START", [alice, bob, charlie])
    alice.edit(lunch, "title", "Taco Bell")
    alice.vote(lunch, "Alice", "up")
    bob.vote(lunch, "Bob", "down")
    charlie.vote(lunch, "Charlie", "up")
    show("OFFLINE COPIES", [alice, bob, charlie])
    replicas = reconnect([alice, bob, charlie], Path("evidence/scenario_2"))
    show("RECONNECTED: ALL COPIES AGREE", replicas)
    row = replicas[0].rows()[0]
    assert (row["title"], row["upvotes"], row["downvotes"], row["votes"]) == ("Taco Bell", 2, 1, 1)
    report("PASS: Taco Bell is on the schedule: 2 upvotes, 1 downvote, net score +1.")
    report("Votes follow the activity ID across its rename; they do not approve or reject title edits.")

    report("\nSCENARIO 3: CONFLICTING BREAKFAST TIMES SETTLED BY A VOTE")
    alice, bob, charlie = new_group()
    breakfast = alice.add("Breakfast", "08:00")
    bob.merge(alice)
    charlie.merge(alice)
    show("SHARED START", [alice, bob, charlie])
    alice.edit(breakfast, "time", "07:30")
    bob.edit(breakfast, "time", "08:15")
    show("OFFLINE COPIES", [alice, bob, charlie])
    folder = Path("evidence/scenario_3")
    replicas = reconnect([alice, bob, charlie], folder, stage="detected")
    show("RECONNECTED: TIME CONFLICT DETECTED, VOTE OPENED", replicas)
    alice, bob, charlie = replicas
    alice.vote_field(breakfast, "time", "Alice", "07:30")
    bob.vote_field(breakfast, "time", "Bob", "08:15")
    charlie.vote_field(breakfast, "time", "Charlie", "08:15")
    save_all(replicas, folder, "voted")
    show("EACH TRAVELER VOTES ON THEIR OWN DEVICE", replicas)
    sync(replicas)
    show("VOTES SHARED", replicas)
    alice.resolve(breakfast, "time")
    sync(replicas)
    save_all(replicas, folder, "synced")
    show("VOTE CLOSED: WINNING TIME SYNCED TO ALL COPIES", replicas)
    row = replicas[0].rows()[0]
    scores = {o["value"]: o["score"] for o in row["field_votes"]["time"]["options"]}
    assert (row["time"], scores) == ("08:15", {"07:30": 1, "08:15": 2})
    assert (row["upvotes"], row["downvotes"]) == (0, 0)
    report("PASS: 08:15 wins the Breakfast time vote +2 to +1 and every copy shows Breakfast at 08:15.")
    report("Time votes choose between proposed times for one activity; they are not upvotes or downvotes.")

    report("\nSCENARIO 4: PROPOSED KAYAKING TRIP IS VOTED DOWN")
    alice, bob, charlie = new_group()
    checkin = alice.add("Hotel Check-in", "15:00")
    kayaking = alice.propose("Kayaking", "10:00")
    alice.vote(kayaking, "Alice", "up")
    bob.merge(alice)
    charlie.merge(alice)
    show("SHARED START: ALICE PROPOSES KAYAKING AND UPVOTES IT", [alice, bob, charlie])
    bob.vote(kayaking, "Bob", "down")
    charlie.vote(kayaking, "Charlie", "down")
    show("OFFLINE COPIES", [alice, bob, charlie])
    folder = Path("evidence/scenario_4")
    replicas = reconnect([alice, bob, charlie], folder, stage="tallied")
    show("RECONNECTED: VOTES COMBINED, PROPOSAL STILL OPEN", replicas)
    alice, bob, charlie = replicas
    assert alice.decide(kayaking) == "rejected"
    sync(replicas)
    save_all(replicas, folder, "synced")
    show("VOTE CLOSED: KAYAKING NOT ADDED", replicas)
    rows = replicas[0].rows()
    rejected = replicas[0].rejected_rows()
    assert [row["id"] for row in rows] == [checkin]
    assert [(r["id"], r["upvotes"], r["downvotes"], r["votes"]) for r in rejected] == [(kayaking, 1, 2, -1)]
    report("PASS: Kayaking ends with 1 upvote, 2 downvotes, net score -1, and is not added to the itinerary.")
    Path("evidence/demo_output.txt").write_text("\n".join(output) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
