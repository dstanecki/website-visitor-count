import json
import boto3 

dynamodb = boto3.client('dynamodb')

def lambda_handler(event, context):
    response = dynamodb.update_item(
        TableName='VisitorCount',
        # The primary key of my DynamoDB table is 'id' with string attribute 'count'. Then I also have another element 'visitor_count' with a number value
        Key={
            'id': {
                'S': "count" 
            }
        },
        # increment visitor_count by 1:
        UpdateExpression='SET visitor_count = visitor_count + :val', 
        ExpressionAttributeValues={
            ':val': {
                'N': '1'
            }
        },
        ReturnValues="UPDATED_NEW"
    )
    # Prints the current visitor count number:
    
    # print(response['Attributes']['visitor_count']['N'])

    # Format DynamoDB response into a variable
    responseBody = json.dumps({"count": response['Attributes']['visitor_count']['N']})


    # Create api response object
    apiResponse = {
        "isBase64Encoded": False,
        "statusCode": 200,
        'headers': {
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
        },
        "body": responseBody
    }


    # Return api response object
    return apiResponse