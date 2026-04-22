#!/bin/bash

# Serverless Analytics API - Test Script
# Tests all API endpoints

set -e

echo "🧪 Serverless Analytics API - Test Script"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get API endpoint
if [ -f "deployment-info.txt" ]; then
    API_ENDPOINT=$(grep "API Endpoint:" deployment-info.txt | cut -d' ' -f3)
else
    echo "Enter your API Gateway endpoint:"
    read API_ENDPOINT
fi

if [ -z "$API_ENDPOINT" ]; then
    echo -e "${RED}❌ API endpoint not set${NC}"
    exit 1
fi

echo ""
echo "Testing API: $API_ENDPOINT"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test endpoint
test_endpoint() {
    local method=$1
    local path=$2
    local data=$3
    local expected_code=$4
    local description=$5
    
    echo -n "Testing $description... "
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$API_ENDPOINT$path")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$API_ENDPOINT$path" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" -eq "$expected_code" ]; then
        echo -e "${GREEN}✓ PASSED${NC} (HTTP $http_code)"
        ((TESTS_PASSED++))
        if [ ! -z "$body" ]; then
            echo "  Response: $body" | head -c 100
            echo ""
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (Expected $expected_code, got $http_code)"
        ((TESTS_FAILED++))
        if [ ! -z "$body" ]; then
            echo "  Response: $body"
        fi
    fi
}

echo "================================================"
echo "Running Tests..."
echo "================================================"
echo ""

# Test 1: Health Check
test_endpoint "GET" "/health" "" 200 "Health Check"
echo ""

# Test 2: Create Event - Valid
test_endpoint "POST" "/events" '{"page": "/test", "action": "view"}' 201 "Create Event (Valid)"
echo ""

# Test 3: Create Event - Invalid (missing fields)
test_endpoint "POST" "/events" '{"page": "/test"}' 400 "Create Event (Invalid - missing action)"
echo ""

# Test 4: Get Statistics
test_endpoint "GET" "/stats?period=24h" "" 200 "Get Statistics (24h)"
echo ""

# Test 5: Get Statistics (7 days)
test_endpoint "GET" "/stats?period=7d" "" 200 "Get Statistics (7d)"
echo ""

# Test 6: Get Recent Events
test_endpoint "GET" "/events/recent?limit=10" "" 200 "Get Recent Events (limit=10)"
echo ""

# Test 7: Get Recent Events (default)
test_endpoint "GET" "/events/recent" "" 200 "Get Recent Events (default)"
echo ""

# Test 8: Create Multiple Events
echo "Testing Multiple Events Creation..."
for i in {1..5}; do
    pages=("/home" "/products" "/about" "/contact" "/blog")
    actions=("view" "click" "scroll" "submit")
    
    page=${pages[$RANDOM % ${#pages[@]}]}
    action=${actions[$RANDOM % ${#actions[@]}]}
    
    echo -n "  Event $i: $page - $action... "
    response=$(curl -s -w "%{http_code}" -X POST "$API_ENDPOINT/events" \
        -H "Content-Type: application/json" \
        -d "{\"page\": \"$page\", \"action\": \"$action\"}")
    
    http_code=$(echo "$response" | tail -c 4)
    
    if [ "$http_code" -eq "201" ]; then
        echo -e "${GREEN}✓${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} (HTTP $http_code)"
        ((TESTS_FAILED++))
    fi
done
echo ""

# Test 9: Invalid Endpoint
test_endpoint "GET" "/invalid-endpoint" "" 404 "Invalid Endpoint (404)"
echo ""

# Final Results
echo "================================================"
echo "Test Results"
echo "================================================"
echo ""
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
    echo ""
    echo "🎉 Your API is working perfectly!"
    echo ""
    echo "Next Steps:"
    echo "  1. Run the dashboard: cd dashboard && streamlit run dashboard.py"
    echo "  2. Configure dashboard with API endpoint: $API_ENDPOINT"
    echo "  3. Start sending real events from your app!"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check CloudWatch logs:"
    echo "     aws logs tail /aws/lambda/analytics-api-function --follow"
    echo ""
    echo "  2. Verify Lambda function:"
    echo "     aws lambda get-function --function-name analytics-api-function"
    echo ""
    echo "  3. Check API Gateway:"
    echo "     aws apigateway get-rest-apis"
    exit 1
fi