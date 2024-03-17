def lambda_handler(event, context):
    print(event)

    event['response']['issueTokens'] = True
    event['response']['failAuthentication'] = False

    return event
