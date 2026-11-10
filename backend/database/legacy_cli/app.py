from database import create_trip, get_trip, update_trip, delete_trip, list_trips
from database import get_activities, add_activity, list_activities, update_activity, delete_activity
from botocore.exceptions import BotoCoreError, ClientError


def display_menu():
    print("\n=== SyncTrip AWS Database Manager ===")
    print("1. Create Trip")
    print("2. Get Trip")
    print("3. Update Trip Destination")
    print("4. Delete Trip")
    print("5. List All Trips")
    print("6. Add Activity")
    print("7. View Itinerary")
    print("8. Edit Activity")
    print("9. Delete Activity")
    print("10. Exit")


while True:
    display_menu()

    choice = input("\nSelect an option: ")

    if choice == "1":
        print("\n--- Create Trip ---")

        trip_id = input("Trip ID: ")
        name = input("Trip name: ")
        destination = input("Destination: ")
        start_date = input("Start date (MM-DD-YYYY): ")

        create_trip(trip_id, name, destination, start_date)

    elif choice == "2":
        print("\n--- Get Trip ---")

        trip_id = input("Trip ID: ")
        get_trip(trip_id)

    elif choice == "3":
        print("\n--- Update Trip ---")

        trip_id = input("Trip ID: ")
        new_destination = input("New destination: ")

        update_trip(trip_id, new_destination)

    elif choice == "4":
        print("\n--- Delete Trip ---")

        trip_id = input("Trip ID: ")
        delete_trip(trip_id)

    elif choice == "5":
        list_trips()

    elif choice == "10":
        print("Goodbye!")
        break

    elif choice in ("6", "7", "8", "9"):
        try:
            trip_id = input("Trip ID: ").strip()

            if choice == "6":
                get_activities(trip_id)
                title = input("Activity title: ")
                scheduled_at = input("Date and time (MM-DD-YYYY HH:MM): ")
                location = input("Location: ")
                add_activity(trip_id, title, scheduled_at, location)

            elif choice == "7":
                list_activities(trip_id)

            else:
                activities = list_activities(trip_id)
                if not activities:
                    continue
                activity_id = input("Activity ID: ").strip()
                if activity_id not in activities:
                    raise ValueError("Activity not found in this trip.")

                if choice == "8":
                    print("Leave a field blank to keep its current value.")
                    title = input("New title: ")
                    scheduled_at = input("New date and time (MM-DD-YYYY HH:MM): ")
                    location = input("New location: ")
                    update_activity(trip_id, activity_id, title, scheduled_at, location)
                else:
                    delete_activity(trip_id, activity_id)

        except (ValueError, BotoCoreError, ClientError) as error:
            print("Could not complete activity operation:", error)

    else:
        print("Invalid option. Please choose 1-10.")
