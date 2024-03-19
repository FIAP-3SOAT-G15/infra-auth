import json
import logging
import os

import requests
import boto3

cognito_client = boto3.client("cognito-idp")

USER_POOL_ID = os.environ.get("USER_POOL_ID")
LOAD_BALANCER_DNS = os.environ.get("LOAD_BALANCER_DNS")
TARGET_PORT = os.environ.get("TARGET_PORT")


def lambda_handler(event, context):
    logging.info(event)

    body = json.loads(event.get("body", "{}"))

    email = body.get("email")
    name = body.get("name")
    cpf = body.get("cpf")

    user_attributes = []
    payload = {}

    if cpf:
        username = cpf
        user_attributes.append({"Name": "custom:CPF", "Value": cpf})
        payload["document"] = cpf
    elif email and name:
        username = email
        user_attributes.extend(
            [
                {"Name": "email", "Value": email},
                {"Name": "email_verified", "Value": "true"},
                {"Name": "name", "Value": name},
            ]
        )
        payload["email"] = email
        payload["name"] = name
    else:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": "{ 'message': 'Please provide either CPF or both Email and Name' }",
        }

    headers = {"Content-Type": "application/json"}
    url = f"http://{LOAD_BALANCER_DNS}:{TARGET_PORT}/live/customers"
    response = requests.post(url, json=payload, headers=headers).json()
    print(response)
    customer_id = response["id"]
    user_attributes.append({"Name": "custom:CUSTOMER_ID", "Value": customer_id})

    response = cognito_client.admin_create_user(
        UserPoolId=USER_POOL_ID,
        Username=username,
        UserAttributes=user_attributes,
        MessageAction="SUPPRESS",
    )
    logging.info(response)

    response = cognito_client.admin_add_user_to_group(
        UserPoolId=USER_POOL_ID, Username=username, GroupName="customer"
    )
    logging.info(response)
