################################################
# Running the scripts
# ------------------
# python access_grant.py grant username-or-role
# python access_grant.py revoke username-or-role
################################################

import sys
import logging
import boto3
import json
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

# AWS clients
iam_client = boto3.client('iam')
s3_client = boto3.client('s3')

def get_access_list(bucket_name, key):
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=key)
        content = response['Body'].read().decode('utf-8')
        access_list = json.loads(content)
        return access_list.get('access_list', [])
    except Exception as e:
        logging.error(f"Failed to fetch access list from S3: {e}")
        sys.exit(1)

def grant_access(user_arn):
    try:
        # Example: attach a policy to the user
        policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
        iam_client.attach_user_policy(UserName=user_arn, PolicyArn=policy_arn)
        logging.info(f"Granted ReadOnlyAccess to {user_arn}")
    except ClientError as e:
        logging.error(f"Failed to grant access: {e}")
        sys.exit(1)

def revoke_access(user_arn):
    try:
        policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
        iam_client.detach_user_policy(UserName=user_arn, PolicyArn=policy_arn)
        logging.info(f"Revoked ReadOnlyAccess from {user_arn}")
    except ClientError as e:
        logging.error(f"Failed to revoke access: {e}")
        sys.exit(1)

def main():
    if len(sys.argv) < 3:
        print("Usage: python access_grant.py <grant|revoke> <user-arn>")
        sys.exit(1)

    command = sys.argv[1].lower()
    user_arn = sys.argv[2]

    # S3 bucket and key for access list
    bucket_name = "org-logs-mitigata"
    key = "access-management/access-list.json"

    # Fetch allowed users and roles from S3
    allowed_entities = get_access_list(bucket_name, key)

    # Check if user_arn is in allowed_entities list
    if user_arn not in [entity['name'] for entity in allowed_entities]:
        logging.error(f"Access denied: {user_arn} is not in the allowed access list.")
        sys.exit(1)

    if command == "grant":
        grant_access(user_arn)
    elif command == "revoke":
        revoke_access(user_arn)
    else:
        print("Invalid command. Use 'grant' or 'revoke'.")
        sys.exit(1)

if __name__ == "__main__":
    main()

