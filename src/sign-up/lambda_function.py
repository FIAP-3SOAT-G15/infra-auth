import json
import logging
import os

import boto3
import botocore.exceptions
import psycopg2
import requests

cognito_client = boto3.client('cognito-idp')

USER_POOL_ID = os.environ.get('USER_POOL_ID')

headers = {'X-Aws-Parameters-Secrets-Token': os.environ.get('AWS_SESSION_TOKEN')}
params_extension_endpoint = 'http://localhost:2773/systemsmanager/parameters/get?name='
secrets_extension_endpoint = 'http://localhost:2773/secretsmanager/get?secretId='


def get_param(param_name):
    return json.loads(requests.get(params_extension_endpoint + param_name, headers=headers).text)


def get_secret(secret_id):
    return json.loads(requests.get(secrets_extension_endpoint + secret_id, headers=headers).text)


def internal_error(error):
    logging.error(error)
    return {
        'statusCode': 500,
        'headers': {'Content-Type': 'application/json'},
        'body': "{ 'message': 'Internal server error' }",
    }


def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))

    email = body.get('email')  # TODO: validate email address
    name = body.get('name')  # TODO: validate name
    cpf = body.get('cpf')  # TODO: validate CPF

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
        RDS_PARAMS = get_param(os.environ.get('RDS_PARAM_ID'))
        RDS_SECRETS = get_secret(os.environ.get('RDS_SECRET_ID'))

        response = cognito_client.admin_create_user(
            UserPoolId=USER_POOL_ID,
            Username=username,
            UserAttributes=user_attributes,
            MessageAction='SUPPRESS'
        )

        logging.info(response)

        response = cognito_client.admin_add_user_to_group(
            UserPoolId=USER_POOL_ID,
            Username=username,
            GroupName='customer'
        )

        logging.info(response)

        # try:
        #     conn = psycopg2.connect(
        #         user=RDS_SECRETS['username'], password=RDS_SECRETS['password'],
        #         host=RDS_PARAMS['endpoint'].split(':')[0], port=RDS_PARAMS['port'], dbname=RDS_PARAMS['name']
        #     )
        # except psycopg2.Error as error:
        #     internal_error(error)

        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': "{ 'message': 'User created successfully' }"
        }

    except botocore.exceptions.ClientError as error:
        logging.error(error)

        if error.response['Error']['Code'] == 'UsernameExistsException':
            return {
                'statusCode': 403,
                'headers': {'Content-Type': 'application/json'},
                'body': "{ 'message': 'Unauthorized' }"
            }

        return internal_error(error)

    except Exception as error:
        return internal_error(error)
