# ----------------------------------------------------------------------------------------------------------------# 
# This script monitors EC2 instances 
# and sends notifications to SNS when an instance is unhealthy.
# ----------------------------------------------------------------------------------------------------------------#

# ----------------------------------------------------------------------------------------------------------------#
# Imports
# ----------------------------------------------------------------------------------------------------------------#

import boto3
import logging
import requests

# ----------------------------------------------------------------------------------------------------------------#
# Configuration
# ----------------------------------------------------------------------------------------------------------------#

AWS_REGION = "us-east-1"

AWS_ACCOUNT_ID = "123456789012"

SNS_TOPIC_ARN = f"arn:aws:sns:{AWS_REGION}:{AWS_ACCOUNT_ID}:cloudMonitoring"

ERROR_SUBJECT = "EC2 Status Notification"

MAX_RETRIES = 3

TIMEOUT_SECONDS = 5

ERROR_SUBJECT = "EC2 Status Notification"

# List of services to monitor, each with a name and URL
SERVICES = [
    {'name': 'Service 1', 'url': 'http://[IP_ADDRESS]/#/'},
    {'name': 'Service 2', 'url': 'http://[IP_ADDRESS]/#/'},
    {'name': 'Service 3', 'url': 'http://[IP_ADDRESS]/#/'},
    {'name': 'Service 4', 'url': 'http://[IP_ADDRESS]/#/'},
    {'name': 'Service 5', 'url': 'https://[IP_ADDRESS]/#/'}
    ]


# Set up logging to capture information, warnings, and errors during execution
LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


# ----------------------------------------------------------------------------------------------------------------#
# Send Message to SNS Topic
# ----------------------------------------------------------------------------------------------------------------#
def send_message(subject, body):
    """
    Sends a notification message to an AWS SNS topic.
    
    Args:
        subject (str): Email subject.
        body (str): Email body.

    Returns:
        dict: SNS publish response.
    """
    # Initialize SNS client to interact with AWS SNS service
    sns_client = boto3.client("sns")

    return sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject,
        Message=body
    )


def lambda_handler(event, context):
    """
    Perform health checks against all configured services.

    If any service fails after all retry attempts,
    an SNS notification is sent.

    Returns:
        dict:
            runningServers
            errors
    """

    results = {}
    errors = []

    LOGGER.info("Starting health check for %d services", len(SERVICES))

    for service in SERVICES:

        name = service["name"]
        url = service["url"]

        LOGGER.info("Checking '%s' (%s)", name, url)

        success = False
        last_exception = None

        for attempt in range(1, MAX_RETRIES + 1):

            LOGGER.info(
                "Attempt %d/%d for %s",
                attempt,
                MAX_RETRIES,
                name
            )

            try:

                response = requests.get(
                    url,
                    timeout=TIMEOUT_SECONDS
                )

                LOGGER.info(
                    "%s returned HTTP %s",
                    name,
                    response.status_code
                )

                if response.status_code == 200:

                    results[name] = {
                        "url": url,
                        "statusCode": response.status_code,
                        "body": "Web application status: 200"
                    }

                    success = True
                    break

                LOGGER.warning(
                    "%s returned HTTP %s",
                    name,
                    response.status_code
                )

            except requests.exceptions.RequestException as exc:

                last_exception = exc

                LOGGER.warning(
                    "%s failed on attempt %d/%d: %s",
                    name,
                    attempt,
                    MAX_RETRIES,
                    exc
                )

        if not success:

            message = [
                f"Service : {name}",
                f"URL     : {url}",
                f"Retries : {MAX_RETRIES}"
            ]

            if last_exception:
                message.append(f"Exception : {last_exception}")

            error = "\n".join(message)

            errors.append(error)

            LOGGER.error(error)

    if errors:

        send_message(
            ERROR_SUBJECT,
            "\n\n".join(errors)
        )

        LOGGER.info("SNS notification sent.")

    else:

        LOGGER.info("All services are healthy.")

    return {
        "runningServers": results,
        "errors": errors
    }