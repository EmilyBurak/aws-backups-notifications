import json
import urllib3
import os

# Set the Slack webhook URL in the environment variables
slack_webhook_url = os.environ["SLACK_ENDPOINT"]

http = urllib3.PoolManager()


def handler(event, context):
    # Print the incoming event
    try:
        print("Incoming Event:" + json.dumps(event))
    except Exception as e:
        print(str(e))
        return

    # Extract the SNS message from the event
    sns_message = event["Records"][0]["Sns"]["Message"]

    # Send the SNS message to Slack
    resp = http.request(
        "POST", slack_webhook_url, body=json.dumps({"text": sns_message})
    )

    # Print the response from Slack webhook URL request to the logs
    print(
        {
            "message": sns_message,
            "status_code": resp.status,
            "response": resp.data.decode("utf-8"),
        }
    )
