
# AWS cloud engineer code challenge

## Project Overview
This project implements a serverless data processing pipeline on AWS to handle customer marketing preferences. The pipeline consists of an API Gateway endpoint, a Step Functions state machine, Lambda functions, and a DynamoDB table. It processes incoming customer data, validates it, removes duplicates, and stores opted-in customers' marketing interests in DynamoDB.

## Prerequisites
1. AWS account with necessary permissions
2. Terraform installed
3. Python 3.9
4. AWS CLI configured

#### Setup
1. Clone The repository
```
git clone https://github.com/henro4niger/aws-code-challenge.git
```

2. Navigate to the project directory:
```
cd aws-code-challenge
```

4. Initialize Terraform
```
terraform init
```

5. Review terraform plan
```
terraform plan
```

6. Apply changes
```
terraform apply --auto-approve
```

## Usage
* The API Gateway endpoint accepts POST requests with list customer data (*displayed after the terraform apply*).
* The Step Functions state machine orchestrates the data processing workflow.
* Lambda functions handle data validation, duplicate removal, and data storage.
* Opted-in customer data is stored in the DynamoDB table.

## Testing

Start new execution on the MarketingPreferencesStateMachine state machine by providing input data to the statemachine . The assumed data format is:
```
[
    {
      "Name": "John Doe",
      "Email": "johndoe@example.com",
      "MarketingOptIn": true,
      "MarketingInterests": [
        "product updates",
        "promotions",
        "newsletters"
      ]
    },
    {
      "Name": "Jane Doe",
      "Email": "janedoe@example.com",
      "MarketingOptIn": true,
      "MarketingInterests": [
        "product updates",
        "newsletters"
      ]
    },
    {
      "Name": "John Doe",
      "Email": "johndoe@example.com",
      "MarketingOptIn": false,
      "MarketingInterests": [
        "promotions"
      ]
    }
  ]

```

We can also test it by sending a post request to the api gateway with the request body in the format:
```
{
    "input": "[{\"Name\": \"John Doe\",\"Email\": \"johndoe@example.com\",\"MarketingOptIn\": true,\"MarketingInterests\": [\"product updates\", \"promotions\", \"newsletters\"]}]",
    "stateMachineArn": "arn:aws:states:xxx:yyy:stateMachine:MarketingPreferencesStateMachine"
}
```