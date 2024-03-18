import os
import boto3
import json

cognito_client = boto3.client('cognito-idp')

user_pool_id = os.getenv('USER_POOL_ID')


def lambda_handler(event, context):
    print(event)
    body = json.loads(event.get("body", "{}"))

    email = body.get('email')
    name = body.get('name')
    cpf = body.get('cpf')

    user_attributes = []
    if cpf:
        username = cpf
        user_attributes.append({'Name': 'custom:CPF', 'Value': cpf})
    elif email and name:
        username = email
        user_attributes.extend([
            {'Name': 'email', 'Value': email},
            {'Name': 'email_verified', 'Value': 'true'},
            {'Name': 'name', 'Value': name},
        ])
    else:
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': "{ 'message': 'Please provide either CPF or both Email and Name' }"
        }

    try:
        response = cognito_client.admin_create_user(
            UserPoolId=user_pool_id,
            Username=username,
            UserAttributes=user_attributes,
            MessageAction='SUPPRESS'
        )
        print(response)
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': "{ 'message': 'User created successfully' }"
        }
    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': "{ 'message': 'Error creating user' }"
        }
