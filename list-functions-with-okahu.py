#!/usr/bin/env python3
"""
Script to list all Lambda functions that have OKAHU_API_KEY
"""

import boto3

def list_functions_with_okahu():
    """List all Lambda functions that have OKAHU_API_KEY"""
    lambda_client = boto3.client('lambda')
    
    print("🔍 Finding all Lambda functions with OKAHU_API_KEY...\n")
    
    try:
        response = lambda_client.list_functions()
        functions = response['Functions']
    except Exception as e:
        print(f"❌ Error listing functions: {e}")
        return
    
    found_count = 0
    found_functions = []
    
    for func in functions:
        function_name = func['FunctionName']
        
        try:
            config = lambda_client.get_function_configuration(
                FunctionName=function_name
            )
            
            env_vars = config.get('Environment', {}).get('Variables', {})
            
            if 'OKAHU_API_KEY' in env_vars:
                print(f"✅ {function_name}")
                found_functions.append(function_name)
                found_count += 1
        except Exception as e:
            # Skip functions we can't access
            continue
    
    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"📊 Found {found_count} function(s) with OKAHU_API_KEY")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    if found_count > 0:
        print("\n💡 Tip: Copy the exact function names above and update the script patterns")
    
    return found_functions

if __name__ == "__main__":
    list_functions_with_okahu()

