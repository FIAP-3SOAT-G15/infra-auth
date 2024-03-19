import os
import jwt
from jwt.algorithms import RSAAlgorithm
import requests
from urllib.request import urlopen


REGION = os.environ.get('REGION')
USER_POOL_ID = os.environ.get('USER_POOL_ID')
APP_CLIENT_ID = os.environ.get('CLIENT_ID')

KEYS_URL = f'https://cognito-idp.{REGION}.amazonaws.com/{USER_POOL_ID}/.well-known/jwks.json'
KEYS = requests.get(KEYS_URL).json()['keys']

def lambda_handler(event, context):
    print('event: ', event)

    groups = []

    if 'authorizationToken' in event:
        groups = extract_and_decode_token(event).get('cognito:groups', [])
    
    if 'admin' in event['methodArn'] and 'admin' not in groups:
        return generate_policy('user', 'Deny', event['methodArn'])
    
    return generate_policy('user', 'Allow', event['methodArn'])

def generate_policy(principal_id, effect, resource):
    auth_response = {}
    auth_response['principalId'] = principal_id
    if effect and resource:
        policy_document = {
            'Version': '2012-10-17',
            'Statement': [{
                'Action': 'execute-api:Invoke',
                'Effect': effect,
                'Resource': resource
            }]
        }
        auth_response['policyDocument'] = policy_document
    return auth_response

def extract_and_decode_token(event):
    try:
        token = event['authorizationToken']
        if token.startswith('Bearer '):
            token = token.split(' ')[1]
        headers = jwt.get_unverified_header(token)
        key = [k for k in KEYS if k['kid'] == headers['kid']][0]
        public_key = RSAAlgorithm.from_jwk(key)
        claims = jwt.decode(token, public_key, algorithms = ['RS256'], audience = APP_CLIENT_ID)
        print('claims: ', claims)
        return claims
    except Exception as e:
        print('Error: ', e)
        return generate_policy('user', 'Deny', event['methodArn'])    
