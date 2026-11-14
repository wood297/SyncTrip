from pathlib import Path
from itinerary import Itinerary


# Run both offline trip scenarios and save their results.
def main():
    output = []

    # Print a message and keep a copy for the evidence file.
    def report(message):
        print(message)
        output.append(message)

    # Display each device's schedule, notes, and vote totals.
    def show(label, replicas):
        report("\n" + label)
        for replica in replicas:
            report(f"  {replica.replica_id}")
            for row in replica.rows():
                report(f"    {row['time']} | {row['title']:<14} | "
                       f"up={row['upvotes']} down={row['downvotes']} score={row['votes']:+d}")
                if row["notes"]:
                    report(f"      Notes: {row['notes']}")

    # Save offline copies, simulate a restart and repeated/old messages, then check agreement.
    def reconnect(replicas, folder):
        for replica in replicas:
            replica.save(folder / f"{replica.replica_id}_offline.json")
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
        for replica in replicas:
            replica.save(folder / f"{replica.replica_id}_synced.json")
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
    Path("evidence/demo_output.txt").write_text("\n".join(output) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
