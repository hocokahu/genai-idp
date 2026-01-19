#!/usr/bin/env python3
"""
Local test script for chat_with_document_resolver Lambda function.

This script:
1. Loads environment variables from test/.env
2. Imports index.py
3. Tests the handler function with a mock AppSync GraphQL event

Usage:
    python test/test_local.py
    python test/test_local.py --event test/event.json
"""
import json
import os
import sys
from pathlib import Path
import argparse
from datetime import datetime

# Get the Lambda directory (parent of test directory)
test_dir = Path(__file__).parent.absolute()
lambda_dir = test_dir.parent
sources_dir = lambda_dir.parent.parent.parent  # Go up 3 levels: lambda -> src -> sources
lib_dir = sources_dir / "lib"

# Add paths to sys.path BEFORE setting environment variables
sys.path.insert(0, str(lambda_dir))
sys.path.insert(0, str(lib_dir))

# Load environment variables from .env file
def load_env_from_file(env_file):
    """Load environment variables from a .env file.
    Supports both KEY=VALUE and export KEY=VALUE formats.
    """
    if not env_file.exists():
        print(f"Warning: {env_file} not found. Using defaults.")
        return {}
    
    env_vars = {}
    with open(env_file, 'r') as f:
        for line in f:
            line = line.strip()
            # Skip empty lines and comments
            if not line or line.startswith('#'):
                continue
            # Handle export KEY=VALUE format
            if line.startswith('export '):
                line = line[7:].strip()  # Remove 'export ' prefix
            # Parse KEY=VALUE format
            if '=' in line:
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                env_vars[key] = value
    return env_vars

# Load environment variables from test/.env
env_file = test_dir / ".env"
env_vars = load_env_from_file(env_file)

# Preserve existing shell environment variables and merge with .env file
# Shell environment variables take precedence (don't overwrite them)
env_vars_from_shell = {}
env_vars_from_file = {}
for key, value in env_vars.items():
    if key in os.environ:
        # Variable already set in shell, preserve it
        env_vars_from_shell[key] = os.environ[key]
    else:
        # Variable not in shell, set from .env file
        os.environ[key] = value
        env_vars_from_file[key] = value

# Set defaults for any missing required variables
defaults = {
    "LOG_LEVEL": "INFO",
    "AWS_REGION": "us-west-2"
}

for key, default_value in defaults.items():
    if key not in os.environ:
        os.environ[key] = default_value

print("=" * 70)
print("Testing chat_with_document_resolver Lambda Function")
print("=" * 70)
print(f"Lambda directory: {lambda_dir}")
print(f"Lib directory: {lib_dir}")
print(f"Test directory: {test_dir}")
print(f"Environment file: {env_file}")
print()

# Debug: Show environment variable sources
if env_vars_from_shell:
    print("Environment variables from shell:")
    for key in sorted(env_vars_from_shell.keys()):
        print(f"  {key}={os.environ[key]}")
    print()
if env_vars_from_file:
    print("Environment variables from .env file:")
    for key in sorted(env_vars_from_file.keys()):
        print(f"  {key}={os.environ[key]}")
    print()

# Check monocle_apptrace installation
print("Checking monocle_apptrace installation...")
try:
    import monocle_apptrace
    print(f"✅ monocle_apptrace location: {monocle_apptrace.__file__}")
    if hasattr(monocle_apptrace, '__version__'):
        print(f"✅ monocle_apptrace version: {monocle_apptrace.__version__}")
except ImportError as e:
    print(f"⚠️  WARNING: monocle_apptrace not installed!")
    print(f"   {e}")
    print("   Install with: pip install monocle-apptrace")
    print("   Continuing anyway...")
print()

# Test 1: Import test
print("Test 1: Testing import and monocle_telemetry setup...")
print("-" * 70)
try:
    # This import will execute setup_monocle_telemetry at module level
    import index
    print("✅ Successfully imported index module")
    print("✅ setup_monocle_telemetry executed without errors")
    print(f"✅ Handler function available: {hasattr(index, 'handler')}")
    print(f"✅ get_summarization_model function available: {hasattr(index, 'get_summarization_model')}")
    print(f"✅ get_full_text function available: {hasattr(index, 'get_full_text')}")
    print(f"✅ s3_object_exists function available: {hasattr(index, 's3_object_exists')}")
except ImportError as e:
    print(f"❌ Import failed: {e}")
    print(f"   Make sure you're in the Lambda directory: {lambda_dir}")
    print(f"   Check that lib directory exists: {lib_dir}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
except Exception as e:
    print(f"❌ Error during import/setup: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()

# Test 2: Handler test with mock AppSync GraphQL event
print("Test 2: Testing handler with mock AppSync GraphQL event...")
print("-" * 70)

# Mock Lambda context
class MockContext:
    def __init__(self):
        self.function_name = "ChatWithDocumentResolverFunction"
        self.function_version = "$LATEST"
        self.invoked_function_arn = "arn:aws:lambda:us-west-2:123456789012:function:test"
        self.memory_limit_in_mb = 512
        self.aws_request_id = "test-request-id"
        self.log_group_name = "/aws/lambda/test"
        self.log_stream_name = "test-stream"

# Parse command line arguments
parser = argparse.ArgumentParser(description='Test chat_with_document_resolver Lambda')
parser.add_argument('--event', type=str, default=str(test_dir / "event.json"),
                    help='Path to event JSON file')
args = parser.parse_args()

# Load event from file or use default
event_file = Path(args.event)
if event_file.exists():
    with open(event_file, 'r') as f:
        test_event = json.load(f)
    print(f"✅ Loaded event from: {event_file}")
else:
    # Default AppSync GraphQL event format
    test_event = {
        "arguments": {
            "s3Uri": "lending_package.pdf",
            "prompt": "What is the total amount?",
            "history": [],
            "modelId": "us.amazon.nova-pro-v1:0"
        }
    }
    print(f"⚠️  Event file not found: {event_file}")
    print("   Using default test event")

print(f"Event: {json.dumps(test_event, indent=2)}")
print()

# Check required environment variables
required_vars = ["OUTPUT_BUCKET", "TRACKING_TABLE_NAME", "CONFIGURATION_TABLE_NAME"]
missing_vars = [var for var in required_vars if not os.environ.get(var)]
if missing_vars:
    print(f"⚠️  Warning: Missing environment variables: {', '.join(missing_vars)}")
    print("   The handler may fail or return errors")
    print()

context = MockContext()

try:
    print("Calling handler...")
    result = index.handler(test_event, context)
    print()
    print("=" * 70)
    print("✅ SUCCESS! Handler executed successfully")
    print("=" * 70)
    print("Response:")
    try:
        # Try to parse and pretty print if it's JSON
        if isinstance(result, str):
            parsed = json.loads(result)
            print(json.dumps(parsed, indent=2))
        elif isinstance(result, dict):
            print(json.dumps(result, indent=2))
        else:
            print(result)
    except:
        print(result)
except Exception as e:
    print()
    print("=" * 70)
    print("❌ ERROR during handler execution")
    print("=" * 70)
    print(f"Error: {str(e)}")
    print()
    print("Note: This is expected if:")
    print("  - The document doesn't exist in S3 (OUTPUT_BUCKET)")
    print("  - The document doesn't exist in DynamoDB (TRACKING_TABLE_NAME)")
    print("  - Required environment variables are missing")
    print("  - AWS credentials are not configured")
    print()
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()
print("=" * 70)
print("✅ All tests passed!")
print("=" * 70)
print()
print("Note: Check .monocle/ folder for trace files (may take a few seconds to appear)")
