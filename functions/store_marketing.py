import json
import boto3
import os

# Configure DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_TABLE_NAME']

def lambda_handler(event, context):
    try:
        # Get the data from the previous step
        data = event
        
        # Check if customer has opted-in for marketing
        counter=0
        for data in data:
            if data['MarketingOptIn']:
                # Store customer data in DynamoDB
                dynamodb.Table(table_name).put_item(Item=data)
                counter+=1
        
        # Return success message
        return {
            'statusCode': 200,
            'body': json.dumps(str(counter) + ' Marketing interests records stored successfully')
        }
    except Exception as e:
        # Handle unexpected errors
        return {
            'statusCode': 500,
            'body': json.dumps(f'An error occurred: {str(e)}')
        }