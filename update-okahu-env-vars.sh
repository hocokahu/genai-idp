#!/bin/bash

# Script to update OKAHU_API_KEY and add OKAHU_INGESTION_ENDPOINT
# to all Lambda functions that have OKAHU_API_KEY configured

set -e

# Configuration
NEW_OKAHU_API_KEY="okh_TvXJNYyn_PLj0x0qXRcyafFXRydgA"
OKAHU_INGESTION_ENDPOINT="https://ingest.stage.okahu.ai/api/v1/trace/ingest"

echo "🔍 Finding all Lambda functions with OKAHU_API_KEY..."

# Find all Lambda functions that have OKAHU_API_KEY in their environment variables
FUNCTIONS=$(aws lambda list-functions --query 'Functions[].FunctionName' --output text)

UPDATED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

for FUNCTION_NAME in $FUNCTIONS; do
    echo ""
    echo "Checking: $FUNCTION_NAME"
    
    # Get current environment variables
    ENV_VARS=$(aws lambda get-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --query 'Environment.Variables' \
        --output json 2>/dev/null || echo "null")
    
    if [ "$ENV_VARS" = "null" ] || [ -z "$ENV_VARS" ]; then
        echo "  ⚠️  No environment variables found, skipping..."
        ((SKIPPED_COUNT++))
        continue
    fi
    
    # Check if OKAHU_API_KEY exists
    HAS_OKAHU=$(echo "$ENV_VARS" | jq -r 'has("OKAHU_API_KEY")' 2>/dev/null || echo "false")
    
    if [ "$HAS_OKAHU" != "true" ]; then
        echo "  ⏭️  No OKAHU_API_KEY found, skipping..."
        ((SKIPPED_COUNT++))
        continue
    fi
    
    echo "  ✅ Found OKAHU_API_KEY, updating..."
    
    # Update environment variables: set new OKAHU_API_KEY and add OKAHU_INGESTION_ENDPOINT
    UPDATED_ENV=$(echo "$ENV_VARS" | jq \
        --arg new_key "$NEW_OKAHU_API_KEY" \
        --arg endpoint "$OKAHU_INGESTION_ENDPOINT" \
        '.OKAHU_API_KEY = $new_key | .OKAHU_INGESTION_ENDPOINT = $endpoint')
    
    # Update the Lambda function
    if aws lambda update-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --environment "Variables=$UPDATED_ENV" \
        --output json > /dev/null 2>&1; then
        echo "  ✅ Successfully updated $FUNCTION_NAME"
        ((UPDATED_COUNT++))
    else
        echo "  ❌ Failed to update $FUNCTION_NAME"
        ((ERROR_COUNT++))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "  ✅ Updated: $UPDATED_COUNT functions"
echo "  ⏭️  Skipped: $SKIPPED_COUNT functions"
echo "  ❌ Errors:  $ERROR_COUNT functions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

