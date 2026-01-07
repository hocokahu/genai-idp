#!/bin/bash

# Script to update OKAHU_API_KEY and add OKAHU_INGESTION_ENDPOINT
# for QueryKnowledgeBaseResolverFunction and ChatWithDocumentResolverFunction only

set -e

# Configuration
NEW_OKAHU_API_KEY="okh_TvXJNYyn_PLj0x0qXRcyafFXRydgA"
OKAHU_INGESTION_ENDPOINT="https://ingest.stage.okahu.ai/api/v1/trace/ingest"

# Function name patterns to search for
FUNCTION_PATTERNS=(
    "QueryKnowledgeBaseResolver"
    "ChatWithDocumentResolver"
)

echo "🔍 Finding Lambda functions..."

# Find all Lambda functions
ALL_FUNCTIONS=$(aws lambda list-functions --query 'Functions[].FunctionName' --output text)

UPDATED_COUNT=0
NOT_FOUND_COUNT=0
ERROR_COUNT=0

for PATTERN in "${FUNCTION_PATTERNS[@]}"; do
    echo ""
    echo "Searching for functions matching: $PATTERN"
    
    # Find functions matching the pattern (case-insensitive)
    MATCHING_FUNCTIONS=$(echo "$ALL_FUNCTIONS" | grep -i "$PATTERN" || true)
    
    if [ -z "$MATCHING_FUNCTIONS" ]; then
        echo "  ⚠️  No functions found matching '$PATTERN'"
        ((NOT_FOUND_COUNT++))
        continue
    fi
    
    for FUNCTION_NAME in $MATCHING_FUNCTIONS; do
        echo "  Processing: $FUNCTION_NAME"
        
        # Get current environment variables
        ENV_VARS=$(aws lambda get-function-configuration \
            --function-name "$FUNCTION_NAME" \
            --query 'Environment.Variables' \
            --output json 2>/dev/null || echo "null")
        
        if [ "$ENV_VARS" = "null" ] || [ -z "$ENV_VARS" ]; then
            echo "    ⚠️  No environment variables found"
            ((ERROR_COUNT++))
            continue
        fi
        
        # Check if OKAHU_API_KEY exists
        HAS_OKAHU=$(echo "$ENV_VARS" | jq -r 'has("OKAHU_API_KEY")' 2>/dev/null || echo "false")
        
        if [ "$HAS_OKAHU" != "true" ]; then
            echo "    ⚠️  No OKAHU_API_KEY found in environment variables"
            ((ERROR_COUNT++))
            continue
        fi
        
        echo "    ✅ Found OKAHU_API_KEY, updating..."
        
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
            echo "    ✅ Successfully updated $FUNCTION_NAME"
            ((UPDATED_COUNT++))
        else
            echo "    ❌ Failed to update $FUNCTION_NAME"
            ((ERROR_COUNT++))
        fi
    done
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "  ✅ Updated: $UPDATED_COUNT function(s)"
echo "  ⚠️  Not found: $NOT_FOUND_COUNT pattern(s)"
echo "  ❌ Errors:  $ERROR_COUNT function(s)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ℹ️  Note: No restart needed! Changes take effect immediately for new invocations."

