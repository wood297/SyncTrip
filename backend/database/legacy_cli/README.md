# AWS DynamoDB Skill Exploration

This project was created for ECE 49595 Senior Design Exercise 3. The goal is to learn how to connect to and manage an AWS DynamoDB database using Python and Boto3.

This database prototype is related to SyncTrip, our team's group travel planning application.

## Technologies

- Python
- AWS DynamoDB
- AWS CLI
- Boto3

## Features

The application supports:

- Creating a trip
- Retrieving a trip by ID
- Updating a trip's destination
- Deleting a trip
- Listing all trips

## Database

The application uses an AWS DynamoDB table named `SyncTripTrips`.

The partition key is `trip_id` (String).

Each trip contains:

- `trip_id`
- `name`
- `destination`
- `start_date`
- `status`

## Project Structure

- `app.py` provides the command-line interface.
- `database.py` contains the DynamoDB operations.
- `requirements.txt` contains the Python dependencies.

## Setup

Install the required dependency:

```bash
pip install -r requirements.txt
```

## Exercise 5: Itinerary Activities

Options 6-9 add, view, edit, and delete activities within an existing trip. Option 10 exits.
Each activity has a title, date/time (`MM-DD-YYYY HH:MM`, local 24-hour time),
location, and generated ID. When editing, leave a field blank to keep it.

Activities are saved on the trip in the existing DynamoDB table, so no new
table is needed. Existing trips start with an empty itinerary. Deleting an
activity keeps the trip and deleting a trip removes its activities too.

Run `python app.py`
