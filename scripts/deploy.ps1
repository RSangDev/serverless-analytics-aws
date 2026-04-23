# Serverless Analytics API - Deploy Script (PowerShell)
# For Windows users

$ErrorActionPreference = "Stop"

Write-Host "Serverless Analytics API - Deployment Script" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

# Configuration
$ProjectName = "analytics-api"
$Region = "us-east-2"
$StackName = "$ProjectName-stack"

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Project Name: $ProjectName"
Write-Host "  AWS Region: $Region"
Write-Host "  Stack Name: $StackName"
Write-Host ""

# Check AWS CLI
Write-Host "Checking AWS CLI..." -ForegroundColor Yellow
try {
    $awsVersion = aws --version 2>&1
    Write-Host "[OK] AWS CLI installed" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] AWS CLI not found. Please install it first." -ForegroundColor Red
    exit 1
}

# Check credentials
Write-Host "Checking AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
    Write-Host "[OK] AWS credentials configured" -ForegroundColor Green
    Write-Host "  Account: $($identity.Account)" -ForegroundColor Gray
} catch {
    Write-Host "[ERROR] AWS credentials not configured" -ForegroundColor Red
    Write-Host "Run: aws configure" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Step 1: Packaging Lambda function..." -ForegroundColor Yellow

# Create Lambda zip
Set-Location lambda
if (Test-Path "function.zip") {
    Remove-Item "function.zip"
}
Compress-Archive -Path handler.py -DestinationPath function.zip -Force
Write-Host "[OK] Lambda function packaged" -ForegroundColor Green
Set-Location ..

Write-Host ""
Write-Host "Step 2: Creating deployment bucket..." -ForegroundColor Yellow

# Create unique bucket name
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$bucketName = "$ProjectName-deploy-$timestamp"

try {
    aws s3 mb "s3://$bucketName" --region $Region 2>&1 | Out-Null
    Write-Host "[OK] Deployment bucket created: $bucketName" -ForegroundColor Green
} catch {
    Write-Host "Error creating bucket. Trying alternative name..." -ForegroundColor Yellow
    $bucketName = "$ProjectName-deploy-alt-$timestamp"
    try {
        aws s3 mb "s3://$bucketName" --region $Region 2>&1 | Out-Null
        Write-Host "[OK] Deployment bucket created: $bucketName" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to create S3 bucket" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Step 3: Packaging CloudFormation template..." -ForegroundColor Yellow

# Package template
try {
    aws cloudformation package `
        --template-file cloudformation/template.yaml `
        --s3-bucket $bucketName `
        --output-template-file packaged-template.yaml `
        --region $Region 2>&1 | Out-Null
    
    Write-Host "[OK] Template packaged" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to package template" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 4: Deploying CloudFormation stack..." -ForegroundColor Yellow
Write-Host "  This may take 2-3 minutes..." -ForegroundColor Gray

# Deploy stack
try {
    aws cloudformation deploy `
        --template-file packaged-template.yaml `
        --stack-name $StackName `
        --capabilities CAPABILITY_IAM `
        --parameter-overrides ProjectName=$ProjectName `
        --region $Region
    
    Write-Host "[OK] Stack deployed successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Stack deployment failed" -ForegroundColor Red
    Write-Host "Check CloudFormation console for details" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Step 5: Updating Lambda function code..." -ForegroundColor Yellow

# Get Lambda function name
try {
    $outputs = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $Region `
        --query 'Stacks[0].Outputs' 2>&1 | ConvertFrom-Json

    $functionName = ($outputs | Where-Object { $_.OutputKey -eq "LambdaFunction" }).OutputValue

    # Update Lambda code
    aws lambda update-function-code `
        --function-name $functionName `
        --zip-file fileb://lambda/function.zip `
        --region $Region 2>&1 | Out-Null

    Write-Host "[OK] Lambda function updated" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to update Lambda function" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 6: Retrieving outputs..." -ForegroundColor Yellow

$apiEndpoint = ($outputs | Where-Object { $_.OutputKey -eq "ApiEndpoint" }).OutputValue
$dynamoTable = ($outputs | Where-Object { $_.OutputKey -eq "DynamoDBTable" }).OutputValue

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Stack Outputs:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  API Endpoint:" -ForegroundColor White
Write-Host "    $apiEndpoint" -ForegroundColor Yellow
Write-Host ""
Write-Host "  DynamoDB Table:" -ForegroundColor White
Write-Host "    $dynamoTable" -ForegroundColor Gray
Write-Host ""
Write-Host "  Lambda Function:" -ForegroundColor White
Write-Host "    $functionName" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Test the API:" -ForegroundColor White
Write-Host "   Invoke-WebRequest -Uri $apiEndpoint/health" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Send a test event:" -ForegroundColor White
Write-Host "   `$body = @{page='/home'; action='view'} | ConvertTo-Json" -ForegroundColor Gray
Write-Host "   Invoke-WebRequest -Uri $apiEndpoint/events -Method POST -Body `$body -ContentType 'application/json'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Run the dashboard:" -ForegroundColor White
Write-Host "   cd dashboard" -ForegroundColor Gray
Write-Host "   pip install -r requirements.txt" -ForegroundColor Gray
Write-Host "   streamlit run dashboard.py" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

# Save deployment info
$deploymentInfo = @"
Serverless Analytics API - Deployment Info
==========================================

Deployed: $(Get-Date)
Stack Name: $StackName
AWS Region: $Region

API Endpoint: $apiEndpoint
DynamoDB Table: $dynamoTable
Lambda Function: $functionName

Test Commands (PowerShell):
---------------------------

# Health check
Invoke-WebRequest -Uri $apiEndpoint/health

# Send event
`$body = @{page='/home'; action='view'} | ConvertTo-Json
Invoke-WebRequest -Uri $apiEndpoint/events -Method POST -Body `$body -ContentType 'application/json'

# Get stats
Invoke-WebRequest -Uri $apiEndpoint/stats?period=24h
"@

$deploymentInfo | Out-File -FilePath deployment-info.txt -Encoding UTF8
Write-Host "[OK] Deployment info saved to: deployment-info.txt" -ForegroundColor Green
Write-Host ""