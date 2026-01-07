#!/usr/bin/env python3
"""
Script to update OKAHU_API_KEY and add OKAHU_INGESTION_ENDPOINT
to all Lambda functions that have OKAHU_API_KEY configured.
No rebuild or redeploy needed - updates environment variables directly.
"""

import boto3
import json
import sys

# Configuration
NEW_OKAHU_API_KEY = "okh_TvXJNYyn_PLj0x0qXRcyafFXRydgA"
OKAHU_INGESTION_ENDPOINT = "https://ingest.stage.okahu.ai/api/v1/trace/ingest"

def update_lambda_env_vars():
    """Update environment variables for all Lambda functions with OKAHU_API_KEY"""
    lambda_client = boto3.client('lambda')
    
    print("🔍 Finding all Lambda functions with OKAHU_API_KEY...\n")
    
    # Get all Lambda functions
    try:
        response = lambda_client.list_functions()
        functions = response['Functions']
    except Exception as e:
        print(f"❌ Error listing functions: {e}")
        sys.exit(1)
    
    updated_count = 0
    skipped_count = 0
    error_count = 0
    
    for func in functions:
        function_name = func['FunctionName']
        print(f"Checking: {function_name}")
        
        try:
            # Get current configuration
            config = lambda_client.get_function_configuration(
                FunctionName=function_name
            )
            
            env_vars = config.get('Environment', {}).get('Variables', {})
            
            # Check if OKAHU_API_KEY exists
            if 'OKAHU_API_KEY' not in env_vars:
                print(f"  ⏭️  No OKAHU_API_KEY found, skipping...\n")
                skipped_count += 1
                continue
            
            print(f"  ✅ Found OKAHU_API_KEY, updating...")
            
            # Update environment variables
            updated_env_vars = env_vars.copy()
            updated_env_vars['OKAHU_API_KEY'] = NEW_OKAHU_API_KEY
            updated_env_vars['OKAHU_INGESTION_ENDPOINT'] = OKAHU_INGESTION_ENDPOINT
            
            # Update the function
            lambda_client.update_function_configuration(
                FunctionName=function_name,
                Environment={'Variables': updated_env_vars}
            )
            
            print(f"  ✅ Successfully updated {function_name}\n")
            updated_count += 1
            
        except Exception as e:
            print(f"  ❌ Error updating {function_name}: {e}\n")
            error_count += 1
    
    # Summary
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 Summary:")
    print(f"  ✅ Updated: {updated_count} functions")
    print(f"  ⏭️  Skipped: {skipped_count} functions")
    print(f"  ❌ Errors:  {error_count} functions")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    return updated_count, skipped_count, error_count

if __name__ == "__main__":
    try:
        update_lambda_env_vars()
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)

