# website-visitor-count
This repo includes a Python Lambda function designed to increment a DynamoDB table number attribute and return an API object. It also includes the JavaScript needed to trigger the API and grab the response. 

The website visitor count can be constructed manually or automatically using the included Terraform files. If using Terraform, don't forget to manually add the necessary table attribute to the DynamoDB table (I used 'id' : 'count' and 'visitor_count' : 0). Once you do that, the Lambda function and API Gateway will be fully functional. 
