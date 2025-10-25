# note-apiservice

# 1. Create all directories
mkdir -p app infra scripts policy

# 2. Create all files
touch README.md
touch infra/network.cfn.yaml
touch infra/service.cfn.yaml
touch scripts/log_summarizer.sh
touch scripts/deploy.sh
touch policy/lpa-check.grep

# 3. Make scripts executable
chmod +x scripts/log_summarizer.sh
chmod +x scripts/deploy.sh




File/Folder	Purpose
README.md	Project documentation
app/	(Optional) Tiny HTTP server or use provided image
infra/network.cfn.yaml	VPC, subnets, Security Groups, etc.
infra/service.cfn.yaml	ECR, ECS Fargate (or EC2), ALB, IAM roles/policies
scripts/log_summarizer.sh	Bash task for log summarization
scripts/deploy.sh	End-to-end deployment script
policy/lpa-check.grep	(Optional) Matchers for least-privileged access audit



bash 
Runing infra/network.cfn.yaml
 aws cloudformation deploy \
  --template-file infra/network.cfn.yaml \
  --stack-name note-api-network-dev \
  --parameter-overrides Environment=dev VpcCIDR=10.0.0.0/16 \
  --capabilities CAPABILITY_IAM

bash
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



# Make script executable
chmod +x scripts/deploy.sh

# Deploy to dev
./scripts/deploy.sh dev v1.0.0

# Deploy to prod with commit SHA
./scripts/deploy.sh prod $(git rev-parse --short HEAD)

