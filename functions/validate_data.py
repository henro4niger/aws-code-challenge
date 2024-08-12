import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def validate_data(data):
    # Check if required fields are present
    required_fields = ["Name", "Email", "MarketingOptIn", "MarketingInterests"]
    for field in required_fields:
        if field not in data:
            return False, f"Missing required field: {field}"
    
    # Validate field types
    if not isinstance(data.get("Name"), str):
        return False, "Field 'Name' must be a string"
    
    if not isinstance(data.get("Email"), str) or "@" not in data.get("Email"):
        return False, "Field 'Email' must be a valid email address"
    
    if not isinstance(data.get("MarketingOptIn"), bool):
        return False, "Field 'MarketingOptIn' must be a boolean"
    
    if not isinstance(data.get("MarketingInterests"), list):
        return False, "Field 'MarketingInterests' must be an array"
    
    for item in data.get("MarketingInterests"):
        if not isinstance(item, str):
            return False, "Items in 'MarketingInterests' must be strings"
    
    return True, ""

def lambda_handler(event, context):
    try:
        # Get the list of records from the "event" key
        records = event
        valid_data = []
        
        # Validate each record
        for record in records:
            is_valid, error_message = validate_data(record)
            if not is_valid:
                logger.error(f"Invalid data: {error_message}")
                continue
            valid_data.append(record)
        
        # Return the valid records
        return valid_data
        
    except json.JSONDecodeError:
        # Handle JSON decoding error
        return {"result": "invalid"}
    except Exception as e:
        # Handle unexpected errors
        return {
            'statusCode': 500,
            'body': json.dumps(f'An error occurred: {str(e)}')
        }
