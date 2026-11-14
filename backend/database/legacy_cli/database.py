import boto3
from boto3.dynamodb.conditions import Attr
from datetime import datetime
from uuid import uuid4

#connect to DynamoDB in our region
dynamodb = boto3.resource("dynamodb", region_name="us-east-2")

#connect to SyncTrip table
table = dynamodb.Table("SyncTripTrips")

def create_trip(trip_id, name, destination, start_date):
    table.put_item(
        Item={
            "trip_id": trip_id,
            "name": name,
            "destination": destination,
            "start_date": start_date,
            "status": "planning"
        }
    )

    print(f"Trip '{name}' was successfully created!")

def get_trip(trip_id):
    response = table.get_item(
        Key={
            "trip_id": trip_id
        }
    )

    if "Item" in response:
        trip = response["Item"]

        print("\nTrip found!")
        print("Trip ID:", trip["trip_id"])
        print("Name:", trip["name"])
        print("Destination:", trip["destination"])
        print("Start Date:", trip["start_date"])
        print("Status:", trip["status"])
    else:
        print("Trip not found.")

def update_trip(trip_id, new_destination):
    table.update_item(
        Key={
            "trip_id": trip_id
        },
        UpdateExpression="SET destination = :destination",
        ExpressionAttributeValues={
            ":destination": new_destination
        }
    )

    print(f"Trip '{trip_id}' was successfully updated!")

def delete_trip(trip_id):
    table.delete_item(
        Key={
            "trip_id": trip_id
        }
    )

    print(f"Trip '{trip_id}' was successfully deleted!")

def list_trips():
    response = table.scan()
    trips = response["Items"]

    if len(trips) == 0:
        print("No trips found.")
        return

    print("\nAll Trips:")

    for trip in trips:
        print("--------------------")
        print("Trip ID:", trip["trip_id"])
        print("Name:", trip["name"])
        print("Destination:", trip["destination"])
        print("Start Date:", trip["start_date"])
        print("Status:", trip["status"])

def get_activities(trip_id):
    response = table.get_item(Key={"trip_id": trip_id}, ConsistentRead=True)
    if "Item" not in response:
        raise ValueError("Trip not found.")
    return response["Item"].get("activities", {})


def save_activities(trip_id, activities, previous):
    condition = Attr("activities").eq(previous)
    if not previous:
        condition = condition | Attr("activities").not_exists()
    try:
        table.update_item(
            Key={"trip_id": trip_id},
            UpdateExpression="SET activities = :activities",
            ExpressionAttributeValues={":activities": activities},
            ConditionExpression=Attr("trip_id").exists() & condition
        )
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        raise ValueError("Trip changed or was deleted. View the itinerary and try again.") from None


def validate_activity(title, scheduled_at, location):
    if not title.strip() or not location.strip():
        raise ValueError("Activity title and location cannot be blank.")
    try:
        date = datetime.strptime(scheduled_at, "%m-%d-%Y %H:%M")
        if date.strftime("%m-%d-%Y %H:%M") != scheduled_at:
            raise ValueError
    except ValueError:
        raise ValueError("Use a valid date and time: MM-DD-YYYY HH:MM.") from None
    return date.strftime("%Y-%m-%d %H:%M")


def add_activity(trip_id, title, scheduled_at, location):
    title, scheduled_at, location = title.strip(), scheduled_at.strip(), location.strip()
    scheduled_at = validate_activity(title, scheduled_at, location)
    previous = get_activities(trip_id)
    activities = dict(previous)
    activity_id = uuid4().hex
    activities[activity_id] = {
        "title": title,
        "scheduled_at": scheduled_at,
        "location": location
    }
    save_activities(trip_id, activities, previous)
    print("Activity created! Activity ID:", activity_id)


def list_activities(trip_id):
    activities = get_activities(trip_id)
    if not activities:
        print("No activities found for this trip.")
    for activity_id, activity in sorted(activities.items(), key=lambda item: item[1]["scheduled_at"]):
        print("--------------------")
        print("Activity ID:", activity_id)
        print("Title:", activity["title"])
        print("Date and Time:", datetime.strptime(activity["scheduled_at"], "%Y-%m-%d %H:%M").strftime("%m-%d-%Y %H:%M"))
        print("Location:", activity["location"])
    return activities


def update_activity(trip_id, activity_id, title, scheduled_at, location):
    previous = get_activities(trip_id)
    if activity_id not in previous:
        raise ValueError("Activity not found in this trip.")
    activity = dict(previous[activity_id])
    activity["title"] = title.strip() or activity["title"]
    scheduled_at = scheduled_at.strip() or datetime.strptime(activity["scheduled_at"], "%Y-%m-%d %H:%M").strftime("%m-%d-%Y %H:%M")
    activity["location"] = location.strip() or activity["location"]
    activity["scheduled_at"] = validate_activity(activity["title"], scheduled_at, activity["location"])
    activities = dict(previous)
    activities[activity_id] = activity
    save_activities(trip_id, activities, previous)
    print("Activity updated!")


def delete_activity(trip_id, activity_id):
    previous = get_activities(trip_id)
    if activity_id not in previous:
        raise ValueError("Activity not found in this trip.")
    activities = dict(previous)
    del activities[activity_id]
    save_activities(trip_id, activities, previous)
    print("Activity deleted!")


#create_trip(
#    "trip1",
#    "Scotland trip",
#    "Edinburgh",
#    "10/15/26"
#)

#update_trip("trip1", "Glasgow")
#get_trip("trip1")

#delete_trip("trip1")
#get_trip("trip1")

#create_trip(
#    "trip001",
#    "Scotland Trip",
#    "Edinburgh",
#    "2026-10-15"
#)

#create_trip(
#    "trip002",
#    "Senior Trip",
#    "Chicago",
#    "2027-03-13"
#)

#create_trip(
#    "trip003",
#    "Beach Trip",
#    "Miami",
#    "2027-05-20"
#)

#list_trips()
