# note-apiservice

# Prerequisites
- AWS CLI

- Docker

- Trivy (for security scanning)

- CloudFormation CLI & cfn-lint (for template validation)

- Python 3.11+

- At least 2GB RAM  5GB free disk space (for local Docker and build operations)

# 1. Create all Files and  directories
```
mkdir -p app infra scripts policy

#Create all files
touch README.md
touch infra/network.cfn.yaml
touch infra/service.cfn.yaml
touch scripts/log_summarizer.sh
touch scripts/deploy.sh
touch policy/lpa-check.grep
```

# 2. Project Layout
| File/Folder               | Purpose                                      |
|--------------------------|----------------------------------------------|
| README.md                | Project documentation                         |
| app/                     | (Optional) Tiny HTTP server or use provided image |
| infra/network.cfn.yaml   | VPC, subnets, Security Groups, etc.          |
| infra/service.cfn.yaml   | ECR, ECS Fargate (or EC2), ALB, IAM roles/policies |
| scripts/log_summarizer.sh| Bash task for log summarization               |
| scripts/deploy.sh        | End-to-end deployment script                   |
| policy/lpa-check.grep    | (Optional) Matchers for least-privileged access audit |

```
text
├─ README.md
├─ app/                  # Optional: HTTP server or app source/image
├─ infra/
│  ├─ network.cfn.yaml   # VPC, subnets, security groups, etc.
│  └─ service.cfn.yaml   # ECR repo, ECS Fargate/EC2, ALB, IAM roles/policies
├─ scripts/
│  ├─ deploy.sh          # Deployment script for build, push, deploy
│  ├─ log_summarizer.sh  # Bash script to summarize logs
│  └─ access_grant.py    # Python script to grant/revoke access (IAM/user roles)
└─ policy/
   └─ lpa-check.grep     # Optional policy checker patterns
```

# 3. Architecture
![Note API Architecture](https://github.com/hariingit/note-apiservice/raw/main/noteapiarchitecture.svg)


- Deploy a VPC with public and private subnets, security groups for network isolation.

- Push container images to ECR and run the Note API service on ECS Fargate.

- Use an Application Load Balancer to route traffic to ECS tasks.

- Manage infrastructure as code with CloudFormation templates for repeatability.

- Automate deployment and logging with bash scripts and apply least-privileged IAM policies.


# 4. Depoly Network stack 
Runing infra/network.cfn.yaml
```
 aws cloudformation deploy \
  --template-file infra/network.cfn.yaml \
  --stack-name note-api-network-dev \
  --parameter-overrides Environment=dev VpcCIDR=10.0.0.0/16 \
  --capabilities CAPABILITY_IAM
```

# 5. Deploy Service Stack

```
aws cloudformation deploy \
  --template-file service.cfn.yaml \
  --stack-name note-api-service-dev \
  --parameter-overrides \
    Environment=dev \
    LogsBucketName=org-logs-mitigata \
    VpcId=/network/dev/vpc-id \
    PublicSubnet1=/network/dev/public-subnet-1 \
    PublicSubnet2=/network/dev/public-subnet-2 \
    PrivateSubnet1=/network/dev/private-subnet-1 \
    PrivateSubnet2=/network/dev/private-subnet-2 \
  --capabilities CAPABILITY_NAMED_IAM
```

# 6. Run Log Summarizer

```
# Usage:
#chmod +x scripts/log_summarizer.sh
#   ./log_summarizer.sh <input_dir> <output_file>
#
# Example:
#   ./log_summarizer.sh sample-logs out.jsonl
```

# 7. Run deploy.sh script

```
# Make script executable
chmod +x scripts/deploy.sh
# Deploy to dev
./scripts/deploy.sh dev v1.0.0

# Deploy to prod with commit SHA
./scripts/deploy.sh prod $(git rev-parse --short HEAD)
```


# 8. Access grant python script
```
./scripts/log_summarizer.sh logs/summary.log
Grant Access

python3 scripts/access_grant.py grant username-or-role
Revoke Access

python3 scripts/access_grant.py revoke username-or-role
```

# 9. Running cfn-lint
```
usage:
Basic: cfn-lint test.yaml
Ignore a rule: cfn-lint -i E3012 -- test.yaml
Configure a rule: cfn-lint -x E3012:strict=true -t test.yaml
Lint all yaml files in a folder: cfn-lint dir/**/*.yaml
```


# 10. Design Trade-Offs
- Uses CloudFormation for declarative infrastructure automation

- Splits network and service stacks for modularity and reuse

- Uses IAM least privilege roles scoped tightly for security

- Applies multi-AZ private and public subnet design for HA and security

- Automates deployment and access management with scripts for operational efficiency

