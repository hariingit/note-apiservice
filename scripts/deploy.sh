#!/bin/bash
set -e  # Exit on error
set -euo pipefail
# Usage: ./scripts/deploy.sh <env> <version>
# Example: ./scripts/deploy.sh dev v1.3.0

ENV=${1:-dev}
VERSION=${2:-$(git rev-parse --short HEAD)}
DATE_TAG=$(date +%Y%m%d)
REGION="eu-west-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/note-api-${ENV}"
IMAGE_TAG="${ECR_REPO}:${VERSION}"
IMAGE_TAG_DATED="${ECR_REPO}:${VERSION}-${DATE_TAG}"
MAX_SIZE_MB=250

echo "🚀 Deploying note-api to ${ENV} (version: ${VERSION})"

# Step 1: Build Docker image
echo "📦 Building Docker image..."
cd app
docker build -t note-api:${VERSION} .

# Tag for ECR
docker tag note-api:${VERSION} ${IMAGE_TAG}
docker tag note-api:${VERSION} ${IMAGE_TAG_DATED}

# Step 2: Size guard (fail if > 250MB)
echo "📏 Checking image size..."
IMAGE_SIZE=$(docker image inspect note-api:${VERSION} --format='{{.Size}}')
IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))

if [ ${IMAGE_SIZE_MB} -gt ${MAX_SIZE_MB} ]; then
    echo "❌ ERROR: Image size ${IMAGE_SIZE_MB}MB exceeds limit of ${MAX_SIZE_MB}MB"
    exit 1
fi
echo "✅ Image size: ${IMAGE_SIZE_MB}MB (within limit)"

# Step 3: Security scan with Trivy
echo "🔒 Running Trivy security scan..."
trivy image --severity HIGH,CRITICAL --exit-code 1 note-api:${VERSION}
echo "✅ Security scan passed"

# Step 4: Push to ECR
echo "📤 Pushing to ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

docker push ${IMAGE_TAG}
docker push ${IMAGE_TAG_DATED}
echo "✅ Pushed ${IMAGE_TAG}"

# Step 5: Deploy to ECS
echo "🚢 Deploying to ECS..."
CLUSTER_NAME="note-api-${ENV}"
SERVICE_NAME="note-api-${ENV}"
TASK_FAMILY="note-api-${ENV}"

# Get current task definition
CURRENT_TASK_DEF=$(aws ecs describe-task-definition --task-definition ${TASK_FAMILY} --region ${REGION})

# Create new task definition with updated image
NEW_TASK_DEF=$(echo ${CURRENT_TASK_DEF} | jq --arg IMAGE "${IMAGE_TAG}" \
  '.taskDefinition | 
   .containerDefinitions[0].image = $IMAGE | 
   del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')

# Register new task definition
NEW_TASK_ARN=$(aws ecs register-task-definition \
  --region ${REGION} \
  --cli-input-json "${NEW_TASK_DEF}" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "✅ Registered new task definition: ${NEW_TASK_ARN}"

# Update ECS service
aws ecs update-service \
  --region ${REGION} \
  --cluster ${CLUSTER_NAME} \
  --service ${SERVICE_NAME} \
  --task-definition ${NEW_TASK_ARN} \
  --force-new-deployment \
  > /dev/null

echo "⏳ Waiting for service to stabilize..."
aws ecs wait services-stable \
  --region ${REGION} \
  --cluster ${CLUSTER_NAME} \
  --services ${SERVICE_NAME}

echo "✅ Service deployed successfully"

# Step 6: Print ALB URL and health check
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name note-api-service-${ENV} \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text \
  --region ${REGION})

echo ""
echo "🎉 Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Environment: ${ENV}"
echo "Version: ${VERSION}"
echo "ALB URL: https://${ALB_DNS}"
echo ""
echo "Health Check:"
curl -f https://${ALB_DNS}/healthz && echo "✅ Health check passed" || echo "❌ Health check failed"

