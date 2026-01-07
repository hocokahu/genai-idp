#!/usr/bin/env python3
"""
Script to update OKAHU_API_KEY and add OKAHU_INGESTION_ENDPOINT
for QueryKnowledgeBaseResolverFunction and ChatWithDocumentResolverFunction only.
No rebuild or redeploy needed - updates environment variables directly.

Usage:
    python3 update-okahu-specific-functions.py
    python3 update-okahu-specific-functions.py --exact "FunctionName1" "FunctionName2"
"""

import boto3
import sys
import argparse

# Configuration
NEW_OKAHU_API_KEY = "okh_TvXJNYyn_PLj0x0qXRcyafFXRydgA"
OKAHU_INGESTION_ENDPOINT = "https://ingest.stage.okahu.ai/api/v1/trace/ingest"

# Function name patterns to search for (case-insensitive)
DEFAULT_FUNCTION_PATTERNS = [
    "QueryKnowledgeBaseResolver",
    "ChatWithDocumentResolver",
]

def update_specific_functions(exact_names=None, patterns=None):
    """Update environment variables for specific Lambda functions"""
    lambda_client = boto3.client('lambda')
    
    print("🔍 Finding Lambda functions...\n")
    
    # Get all Lambda functions
    try:
        response = lambda_client.list_functions()
        all_functions = {f['FunctionName']: f for f in response['Functions']}
    except Exception as e:
        print(f"❌ Error listing functions: {e}")
        sys.exit(1)
    
    updated_count = 0
    not_found_count = 0
    error_count = 0
    
    # If exact names provided, use those directly
    if exact_names:
        functions_to_update = []
        for exact_name in exact_names:
            if exact_name in all_functions:
                functions_to_update.append(exact_name)
            else:
                print(f"⚠️  Function '{exact_name}' not found in AWS account")
                not_found_count += 1
        
        # Process exact function names
        for function_name in functions_to_update:
            result = update_function(lambda_client, function_name)
            if result == "updated":
                updated_count += 1
            elif result == "error":
                error_count += 1
        
        # Print summary and return
        print_summary(updated_count, not_found_count, error_count)
        return updated_count, not_found_count, error_count
    
    # Otherwise, use patterns
    if patterns is None:
        patterns = DEFAULT_FUNCTION_PATTERNS
    
    for pattern in patterns:
        print(f"Searching for functions matching: {pattern}")
        
        # Find functions matching the pattern (case-insensitive)
        matching_functions = [
            name for name in all_functions.keys()
            if pattern.lower() in name.lower()
        ]
        
        if not matching_functions:
            print(f"  ⚠️  No functions found matching '{pattern}'\n")
            not_found_count += 1
            continue
        
        for function_name in matching_functions:
            result = update_function(lambda_client, function_name)
            if result == "updated":
                updated_count += 1
            elif result == "error":
                error_count += 1
    
    # Summary
    print_summary(updated_count, not_found_count, error_count)
    
    return updated_count, not_found_count, error_count

def update_function(lambda_client, function_name):
    """Update a single Lambda function's environment variables"""
    print(f"  Processing: {function_name}")
    
    try:
        # Get current configuration
        config = lambda_client.get_function_configuration(
            FunctionName=function_name
        )
        
        env_vars = config.get('Environment', {}).get('Variables', {})
        
        if not env_vars:
            print(f"    ⚠️  No environment variables found\n")
            return "error"
        
        # Check if OKAHU_API_KEY exists
        if 'OKAHU_API_KEY' not in env_vars:
            print(f"    ⚠️  No OKAHU_API_KEY found in environment variables\n")
            return "error"
        
        print(f"    ✅ Found OKAHU_API_KEY, updating...")
        
        # Update environment variables
        updated_env_vars = env_vars.copy()
        updated_env_vars['OKAHU_API_KEY'] = NEW_OKAHU_API_KEY
        updated_env_vars['OKAHU_INGESTION_ENDPOINT'] = OKAHU_INGESTION_ENDPOINT
        
        # Update the function
        lambda_client.update_function_configuration(
            FunctionName=function_name,
            Environment={'Variables': updated_env_vars}
        )
        
        print(f"    ✅ Successfully updated {function_name}\n")
        return "updated"
        
    except Exception as e:
        print(f"    ❌ Error updating {function_name}: {e}\n")
        return "error"

def print_summary(updated_count, not_found_count, error_count):
    """Print summary of updates"""
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 Summary:")
    print(f"  ✅ Updated: {updated_count} function(s)")
    print(f"  ⚠️  Not found: {not_found_count} pattern(s)")
    print(f"  ❌ Errors:  {error_count} function(s)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
    print("ℹ️  Note: No restart needed! Changes take effect immediately for new invocations.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Update OKAHU environment variables for specific Lambda functions"
    )
    parser.add_argument(
        "--exact",
        nargs="+",
        help="Exact function names to update (e.g., --exact FunctionName1 FunctionName2)"
    )
    parser.add_argument(
        "--pattern",
        nargs="+",
        help="Patterns to search for in function names (default: QueryKnowledgeBaseResolver, ChatWithDocumentResolver)"
    )
    
    args = parser.parse_args()
    
    try:
        if args.exact:
            update_specific_functions(exact_names=args.exact)
        elif args.pattern:
            update_specific_functions(patterns=args.pattern)
        else:
            update_specific_functions()
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)

