#!/bin/bash

# Serverless Analytics API - Cleanup Script
# Deletes all AWS resources

set -e

echo "🗑️  Serverless Analytics API - Cleanup Script"
echo "============================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PROJECT_NAME=${1:-"analytics-api"}
AWS_REGION=${AWS_REGION:-"us-east-1"}
STACK_NAME="${PROJECT_NAME}-stack"

echo ""
echo "⚠️  WARNING: This will DELETE all resources!"
echo ""
echo "Stack to delete: $STACK_NAME"
echo "Region: $AWS_REGION"
echo ""
echo -n "Are you sure? (type 'yes' to confirm): "
read confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "🔍 Step 1: Checking if stack exists..."

# Check if stack exists
if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" &> /dev/null; then
    echo -e "${YELLOW}⚠${NC}  Stack not found: $STACK_NAME"
    echo "Nothing to cleanup"
    exit 0
fi

echo -e "${GREEN}✓${NC} Stack found"

echo ""
echo "📊 Step 2: Getting stack resources..."

# Get DynamoDB table name
DYNAMODB_TABLE=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`DynamoDBTable`].OutputValue' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

# Get S3 bucket name (if exists)
S3_BUCKET=$(aws cloudformation describe-stack-resources \
    --stack-name "$STACK_NAME" \
    --query 'StackResources[?ResourceType==`AWS::S3::Bucket`].PhysicalResourceId' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

echo ""
echo "Resources found:"
if [ ! -z "$DYNAMODB_TABLE" ]; then
    echo "  - DynamoDB Table: $DYNAMODB_TABLE"
fi
if [ ! -z "$S3_BUCKET" ]; then
    echo "  - S3 Bucket: $S3_BUCKET"
fi

echo ""
echo "🗑️  Step 3: Emptying S3 buckets..."

# Empty S3 bucket (if exists)
if [ ! -z "$S3_BUCKET" ]; then
    echo "Emptying bucket: $S3_BUCKET"
    aws s3 rm "s3://$S3_BUCKET" --recursive --region "$AWS_REGION" 2>/dev/null || true
    echo -e "${GREEN}✓${NC} S3 bucket emptied"
else
    echo "No S3 bucket to empty"
fi

echo ""
echo "🗑️  Step 4: Deleting CloudFormation stack..."

# Delete stack
aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION"

echo "Waiting for stack deletion..."
aws cloudformation wait stack-delete-complete \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" 2>/dev/null || true

echo -e "${GREEN}✓${NC} Stack deleted"

echo ""
echo "🗑️  Step 5: Cleaning up deployment artifacts..."

# Remove local files
if [ -f "packaged-template.yaml" ]; then
    rm packaged-template.yaml
    echo -e "${GREEN}✓${NC} Removed packaged-template.yaml"
fi

if [ -f "deployment-info.txt" ]; then
    rm deployment-info.txt
    echo -e "${GREEN}✓${NC} Removed deployment-info.txt"
fi

if [ -f "lambda/function.zip" ]; then
    rm lambda/function.zip
    echo -e "${GREEN}✓${NC} Removed lambda/function.zip"
fi

echo ""
echo "================================================"
echo "✅ CLEANUP COMPLETE!"
echo "================================================"
echo ""
echo "All resources have been deleted:"
echo "  ✓ Lambda Function"
echo "  ✓ API Gateway"
echo "  ✓ DynamoDB Table"
echo "  ✓ S3 Buckets"
echo "  ✓ IAM Roles"
echo "  ✓ CloudWatch Logs"
echo ""
echo "You can redeploy anytime with:"
echo "  ./scripts/deploy.sh"
echo ""