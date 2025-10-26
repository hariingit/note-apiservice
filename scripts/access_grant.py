################################################
Runing the scripts
------------------
python access_grant.py grant username-or-role
python access_grant.py revoke username-or-role
################################################


import sys
import logging
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

iam_client = boto3.client('iam')

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

    if command == "grant":
        grant_access(user_arn)
    elif command == "revoke":
        revoke_access(user_arn)
    else:
        print("Invalid command. Use 'grant' or 'revoke'.")
        sys.exit(1)

if __name__ == "__main__":
    main()

