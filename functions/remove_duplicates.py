import json

def lambda_handler(event, context):
    # Get the data from the event (list of records)
    data = event  # This is now a list of dictionaries
    
    # Using a set to track seen emails
    seen = set()
    unique_data = []

    # Loop through each record in the list
    for record in data:
        if record['Email'] not in seen:
            seen.add(record['Email'])
            unique_data.append(record)
    
    # Return the unique data
    return unique_data
