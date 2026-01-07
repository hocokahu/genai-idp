#!/bin/bash

# Script to list all Lambda functions that have OKAHU_API_KEY

echo "🔍 Finding all Lambda functions with OKAHU_API_KEY...\n"

# Get all Lambda functions
FUNCTIONS=$(aws lambda list-functions --query 'Functions[].FunctionName' --output text)

FOUND_COUNT=0

for FUNCTION_NAME in $FUNCTIONS; do
    # Get current environment variables
    ENV_VARS=$(aws lambda get-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --query 'Environment.Variables' \
        --output json 2>/dev/null || echo "null")
    
    if [ "$ENV_VARS" = "null" ] || [ -z "$ENV_VARS" ]; then
        continue
    fi
    
    # Check if OKAHU_API_KEY exists
    HAS_OKAHU=$(echo "$ENV_VARS" | jq -r 'has("OKAHU_API_KEY")' 2>/dev/null || echo "false")
    
    if [ "$HAS_OKAHU" = "true" ]; then
        echo "✅ $FUNCTION_NAME"
        ((FOUND_COUNT++))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Found $FOUND_COUNT function(s) with OKAHU_API_KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

