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

MAX_RETRIES = 3

TIMEOUT_SECONDS = 5

ERROR_SUBJECT = "EC2 Status Notification"

# List of services to monitor, each with a name and URL
services = [
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
    Sends a notification message to an AWS SNS (Simple Notification Service) topic.
    
    Args:
        subject (str): The subject line for the notification
        body (str): The content/body of the notification message
        
    Returns:
        dict: The response from the SNS publish operation
    """

    # Publish the message to the specified SNS topic with subject and body
    response = sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject,
        Message=body
    )

    return response

def lambda_handler(event, context):
    """
    AWS Lambda function that performs health checks on multiple services.
    For each service, it sends HTTP requests and verifies if they respond with status code 200.
    If a service fails after multiple attempts, it sends an error notification via SNS.
    
    Args:
        event: AWS Lambda event object (not used in this function)
        context: AWS Lambda context object (not used in this function)
        
    Returns:
        dict: Contains two keys:
            - 'runningServers': Dictionary of services that responded successfully
            - 'errors': List of error messages for services that failed
    """

    # Dictionary to store results of successful health checks
    results = {}
    # List to store error messages for failed health checks
    errors = []

    # Log the start of the health check process
    LOGGER.info("Starting health check for %d services", len(services))
    
    # Iterate through each service to perform health checks
    for service in services:
        name = service['name']
        url = service['url']
        LOGGER.info("Checking service '%s' at %s", name, url)
        success = False
        last_exception = None
        
        # Retry logic for each service
        for attempt in range(1, MAX_RETRIES + 1):
            LOGGER.info("Attempt %d/%d for '%s'", attempt, MAX_RETRIES, name)
            try:
                # Send HTTP GET request to the service URL with timeout
                response = requests.get(url, timeout=TIMEOUT_SECONDS)
                status_code = response.status_code
                LOGGER.info(
                    "Service '%s' responded with status %s",
                    name,
                    status_code
                )
                # Check if the service responded with a success status code
                if status_code == 200:
                    results[name] = {
                        'url': url,
                        'statusCode': status_code,
                        'body': 'Web application status: 200'
                    }
                    success = True
                    break  # Exit the retry loop if successful
                else:
                    LOGGER.warning(
                        "Service '%s' returned non-200 status: %s",
                        name,
                        status_code
                    )
            except requests.exceptions.RequestException as exc:
                # Store the last exception for error reporting
                last_exception = exc
                LOGGER.warning(
                    "Request error for '%s' (attempt %d/%d): %s",
                    name,
                    attempt,
                    MAX_RETRIES,
                    exc
                )

        # If all retry attempts failed, prepare an error message
        if not success:
            message_lines = [
                f"Failed to get a successful response from service '{name}'",
                f"URL: {url}",
                f"Attempts: {MAX_RETRIES}",
            ]
            if last_exception:
                message_lines.append(f"Last exception: {last_exception}")
            error_message = ' | '.join(message_lines)
            errors.append(error_message)
            LOGGER.error(error_message)
        
    # If there are any errors, send a notification via SNS
    if errors:
        # Concatenate all error messages into one string
        error_message = '\n'.join(errors)
        # Send error message to SNS topic
        subject = ERROR_SUBJECT
        send_message(subject, error_message)
        LOGGER.info("Error notification sent via SNS with subject '%s'", subject)
    else:
        LOGGER.info("All services responded successfully")
    
    # Return the results of the health checks
    return {
        'runningServers': results,
        'errors': errors
    }