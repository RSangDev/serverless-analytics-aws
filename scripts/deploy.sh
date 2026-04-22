#!/bin/bash

# Serverless Analytics API - Deploy Script
# Automates CloudFormation deployment

set -e

echo "🚀 Serverless Analytics API - Deployment Script"
echo "================================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME=${1:-"analytics-api"}
AWS_REGION=${AWS_REGION:-"us-east-1"}
STACK_NAME="${PROJECT_NAME}-stack"
DEPLOYMENT_BUCKET="${PROJECT_NAME}-deployment-$(date +%s)"

echo ""
echo "📋 Configuration:"
echo "  Project Name: $PROJECT_NAME"
echo "  AWS Region: $AWS_REGION"
echo "  Stack Name: $STACK_NAME"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install it first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} AWS CLI installed"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi
echo -e "${GREEN}✓${NC} AWS credentials configured"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓${NC} AWS Account: $AWS_ACCOUNT_ID"

echo ""
echo "📦 Step 1: Packaging Lambda function..."

# Create lambda zip
cd lambda
if [ -f "function.zip" ]; then
    rm function.zip
fi
zip -q function.zip handler.py
echo -e "${GREEN}✓${NC} Lambda function packaged"
cd ..

echo ""
echo "☁️  Step 2: Creating deployment bucket..."

# Create S3 bucket for deployment
if aws s3 ls "s3://$DEPLOYMENT_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb "s3://$DEPLOYMENT_BUCKET" --region "$AWS_REGION"
    echo -e "${GREEN}✓${NC} Deployment bucket created: $DEPLOYMENT_BUCKET"
else
    echo -e "${YELLOW}⚠${NC}  Bucket already exists: $DEPLOYMENT_BUCKET"
fi

echo ""
echo "📤 Step 3: Uploading CloudFormation template..."

# Package CloudFormation template
aws cloudformation package \
    --template-file cloudformation/template.yaml \
    --s3-bucket "$DEPLOYMENT_BUCKET" \
    --output-template-file packaged-template.yaml \
    --region "$AWS_REGION"

echo -e "${GREEN}✓${NC} Template packaged"

echo ""
echo "🚀 Step 4: Deploying CloudFormation stack..."

# Deploy stack
aws cloudformation deploy \
    --template-file packaged-template.yaml \
    --stack-name "$STACK_NAME" \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides ProjectName="$PROJECT_NAME" \
    --region "$AWS_REGION"

echo -e "${GREEN}✓${NC} Stack deployed"

echo ""
echo "🔄 Step 5: Updating Lambda function code..."

# Get Lambda function name
FUNCTION_NAME=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunction`].OutputValue' \
    --output text \
    --region "$AWS_REGION")

# Update Lambda code
aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file fileb://lambda/function.zip \
    --region "$AWS_REGION" > /dev/null

echo -e "${GREEN}✓${NC} Lambda function updated"

echo ""
echo "📊 Step 6: Retrieving stack outputs..."

# Get stack outputs
OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs' \
    --region "$AWS_REGION")

API_ENDPOINT=$(echo "$OUTPUTS" | grep -A1 "ApiEndpoint" | grep "OutputValue" | cut -d'"' -f4)
DYNAMODB_TABLE=$(echo "$OUTPUTS" | grep -A1 "DynamoDBTable" | grep "OutputValue" | cut -d'"' -f4)
LAMBDA_FUNCTION=$(echo "$OUTPUTS" | grep -A1 "LambdaFunction" | grep "OutputValue" | cut -d'"' -f4)

echo ""
echo "================================================"
echo "✅ DEPLOYMENT SUCCESSFUL!"
echo "================================================"
echo ""
echo "📌 Stack Outputs:"
echo ""
echo "  API Endpoint:"
echo -e "    ${GREEN}$API_ENDPOINT${NC}"
echo ""
echo "  DynamoDB Table:"
echo "    $DYNAMODB_TABLE"
echo ""
echo "  Lambda Function:"
echo "    $LAMBDA_FUNCTION"
echo ""
echo "================================================"
echo ""
echo "🧪 Next Steps:"
echo ""
echo "1. Test the API:"
echo "   curl $API_ENDPOINT/health"
echo ""
echo "2. Send a test event:"
echo "   curl -X POST $API_ENDPOINT/events \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"page\": \"/home\", \"action\": \"view\"}'"
echo ""
echo "3. Run the dashboard:"
echo "   cd dashboard"
echo "   streamlit run dashboard.py"
echo ""
echo "4. Configure dashboard with API endpoint:"
echo -e "   ${GREEN}$API_ENDPOINT${NC}"
echo ""
echo "================================================"
echo ""

# Save outputs to file
cat > deployment-info.txt << EOF
Serverless Analytics API - Deployment Info
==========================================

Deployed: $(date)
Stack Name: $STACK_NAME
AWS Region: $AWS_REGION
AWS Account: $AWS_ACCOUNT_ID

API Endpoint: $API_ENDPOINT
DynamoDB Table: $DYNAMODB_TABLE
Lambda Function: $LAMBDA_FUNCTION

Test Commands:
--------------
# Health check
curl $API_ENDPOINT/health

# Send event
curl -X POST $API_ENDPOINT/events \\
  -H 'Content-Type: application/json' \\
  -d '{"page": "/home", "action": "view"}'

# Get stats
curl $API_ENDPOINT/stats?period=24h

# Get recent events
curl $API_ENDPOINT/events/recent?limit=10
EOF

echo -e "${GREEN}✓${NC} Deployment info saved to: deployment-info.txt"
echo ""