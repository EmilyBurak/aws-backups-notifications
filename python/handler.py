import json
import logging
import os

import urllib3

# Set the Slack webhook URL in the environment variables
slack_webhook_url = os.environ["SLACK_ENDPOINT"]
if not slack_webhook_url:
    raise ValueError("SLACK_ENDPOINT environment variable is not set")

http = urllib3.PoolManager()
logger = logging.getLogger(__name__)
logger.setLevel("INFO")


def handler(event, context):
    # Print the incoming event to the logs
    try:
        logger.info("Incoming Event:" + json.dumps(event))

        # Extract the SNS message from the event
        sns_notification = event["Records"][0]["Sns"]

        # Create the message to be sent to Slack
        sns_message = sns_notification["Message"]
        sns_subject = sns_notification["Subject"]
        sns_timestamp = sns_notification["Timestamp"]
        sns_event_state = sns_notification["MessageAttributes"]["State"]["Value"]
        job_id = sns_notification["MessageAttributes"]["Id"]["Value"]

        slack_message = (
            f"*Subject:* {sns_subject}\n"
            f"*Message:* {sns_message}\n"
            f"*Timestamp*: {sns_timestamp}\n"
            f"*Event State*: AWS Backup Job _{job_id}_ is in state: *{sns_event_state}*"
        )

    except Exception as e:
        logger.error(f"Error processing event: {str(e)}")
        raise

    # Send the SNS message to Slack
    try:
        resp = http.request(
            "POST", slack_webhook_url, body=json.dumps({"text": slack_message})
        )
    except Exception as e:
        logger.error(f"Error sending message to Slack: {str(e)}")
        raise

    # Print the response from Slack webhook URL request to the logs
    logger.info(
        {
            "slack_message": slack_message,
            "status_code": resp.status,
            "response": resp.data.decode("utf-8"),
        }
    )
