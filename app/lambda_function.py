import json
import os
import boto3

cognito = boto3.client('cognito-idp')

USER_POOL_ID = os.getenv('USER_POOL_ID')
CLIENT_ID = os.getenv('CLIENT_ID')

def lambda_handler(event, context):
    body = json.loads(event['body'])

    identifier = body.get('cpf') or body.get('email')

    if not identifier:
        return {
            'statusCode': 400,
            'headers': { 'Content-Type': 'application/json' },
            'body': "{ 'message': 'Identifier (CPF or email) is required' }",
        }

    try:
        response = cognito.admin_initiate_auth(
            UserPoolId = USER_POOL_ID,
            ClientId = CLIENT_ID,
            AuthFlow = 'CUSTOM_AUTH',
            AuthParameters = { 'USERNAME': identifier }
        )
        return {
            'statusCode': 200,
            'headers': { 'Content-Type': 'application/json' },
            'body': response,
        }
    except cognito.exceptions.ClientError as e:
        print(e)
        return {
            'statusCode': 500,
            'headers': { 'Content-Type': 'application/json' },
            'body': "{ 'message': 'Error initiating authentication' }",
        }
