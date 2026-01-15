# Local Testing Guide for query_knowledgebase_resolver

This directory contains test files for locally testing the `query_knowledgebase_resolver` Lambda function, including testing PR 411 changes to `setup_monocle_telemetry`.

## Setup Instructions

### Step 1: Create Virtual Environment

```bash
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/query_knowledgebase_resolver
python3 -m venv .venv
source .venv/bin/activate
```

### Step 2: Install PR 411 (Monocle Apptrace)

PR 411 adds Boto coverage to support API. To install it:

```bash
# Clone monocle repo
git clone https://github.com/monocle2ai/monocle.git tmp/monocle
cd tmp/monocle

# Fetch and checkout PR 411 branch
git fetch https://github.com/beehyv/monocle.git boto_coverage_api:boto_coverage_api
git checkout boto_coverage_api

# Verify you're on the correct branch
git branch
# Should show: * boto_coverage_api

# Verify apptrace directory structure
ls -la apptrace/
# Should show: pyproject.toml, src/, tests/, README.md

# Go back to Lambda directory
cd ../..

# Install PR 411 in editable mode
pip install -e tmp/monocle/apptrace

# Verify installation
python -c "
import monocle_apptrace
print('✅ Location:', monocle_apptrace.__file__)
print('✅ Has setup_monocle_telemetry:', hasattr(monocle_apptrace, 'setup_monocle_telemetry'))
from monocle_apptrace import setup_monocle_telemetry
print('✅ PR 411 setup_monocle_telemetry imported successfully!')
"
```

### Step 3: Install Other Dependencies

```bash
# Make sure you're in the Lambda directory with .venv activated
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/query_knowledgebase_resolver
source .venv/bin/activate

# Install boto3 and other dependencies
pip install boto3

# Install idp_common_pkg (if needed)
pip install -e ../../../lib/idp_common_pkg
```

### Step 4: Configure Environment Variables

Edit `test/.env` with your actual values. The file supports both formats:
- `KEY=VALUE` (standard format)
- `export KEY=VALUE` (shell export format)

Required variables:
- `KB_ID`: Your Bedrock Knowledge Base ID
- `KB_ACCOUNT_ID`: Your AWS Account ID
- `KB_REGION`: Your AWS region (e.g., "us-west-2")
- `AWS_REGION`: Your AWS region (same as KB_REGION)
- `MODEL_ID`: Your Bedrock model inference profile ID
- `LOG_LEVEL`: Logging level (e.g., "INFO", "DEBUG")
- `GUARDRAIL_ID_AND_VERSION`: Optional guardrail (format: "id:version")

Example `test/.env`:
```bash
export KB_ID=JGKAIY9DHE
export KB_ACCOUNT_ID=390041016107
export KB_REGION=us-west-2
export AWS_REGION=us-west-2
export MODEL_ID=us.amazon.nova-pro-v1:0
export LOG_LEVEL=INFO
```

### Step 5: Run the Test

```bash
# From the Lambda directory with .venv activated
source .venv/bin/activate
python test/test_local.py

# Or with a custom event file
python test/test_local.py --event test/event.json
```

## What This Tests

### PR 411: setup_monocle_telemetry Changes

This test script specifically verifies:

1. ✅ **Import Test**: `from monocle_apptrace import setup_monocle_telemetry` works
2. ✅ **Setup Test**: `setup_monocle_telemetry(workflow_name="aws-genai-idp")` executes without errors
3. ✅ **Handler Test**: The Lambda handler function works correctly with the new telemetry setup

The import happens at module level in `index.py` (line 10-11), so the test will immediately catch any issues with PR 411 changes.

## How It Works

1. **Direct Python Import**: The test script imports `index.py` directly as a Python module
   - When Python imports the module, it executes all module-level code
   - This includes the `setup_monocle_telemetry` call on line 11
   - Any errors in PR 411 will be caught immediately

2. **Environment Variables**: Loads from `test/.env` before importing
   - Ensures all required env vars are set
   - Matches the Lambda runtime environment

3. **Handler Execution**: Calls `index.handler(event, context)` directly
   - Uses a mock Lambda context
   - Uses a sample AppSync resolver event
   - Tests the full handler flow

## Test Output

The test will show:
- ✅ Import success/failure
- ✅ Telemetry setup success/failure (PR 411 verification)
- ✅ Handler execution results
- ✅ Full error traces if anything fails

## Troubleshooting

### Import Errors

**Error: `ModuleNotFoundError: No module named 'monocle_apptrace'`**
```bash
# Make sure PR 411 is installed
pip install -e tmp/monocle/apptrace

# Verify installation
python -c "import monocle_apptrace; print(monocle_apptrace.__file__)"
```

**Error: `ModuleNotFoundError: No module named 'idp_common_pkg'`**
- Make sure you're running from `sources/src/lambda/query_knowledgebase_resolver/`
- Check that `sources/lib/idp_common_pkg` exists
- Install it: `pip install -e ../../lib/idp_common_pkg`

### AWS Credentials

The test uses your default AWS credentials:
```bash
aws configure
```

### Missing Environment Variables

Update values in `test/.env`:
```bash
# Required variables
KB_ID=your-kb-id
KB_ACCOUNT_ID=123456789012
KB_REGION=us-east-1
AWS_REGION=us-east-1
MODEL_ID=your-model-id
LOG_LEVEL=INFO
```

### PR 411 Specific Issues

If `setup_monocle_telemetry` fails:
1. Verify PR 411 is installed: `pip list | grep monocle`
2. Check the installation location: `python -c "import monocle_apptrace; print(monocle_apptrace.__file__)"`
3. Verify you're on the correct branch in `tmp/monocle/`
4. Review error messages for specific issues

## File Structure

```
query_knowledgebase_resolver/
├── index.py              # Lambda function (uses PR 411)
├── requirements.txt      # Dependencies
├── .venv/               # Virtual environment
├── tmp/
│   └── monocle/         # PR 411 source code
└── test/
    ├── test_local.py    # Main test script
    ├── event.json        # Sample AppSync event
    ├── .env              # Environment variables (not in git)
    └── README.md         # This file
```

## Deploying to AWS Lambda

After local testing passes, deploy the Lambda function to AWS.

### Target Lambda Function
- **Function Name**: `GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-qbZOx3wS3Vjl`
- **Region**: `us-west-2`
- **Console URL**: https://us-west-2.console.aws.amazon.com/lambda/home?region=us-west-2#/functions/GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-qbZOx3wS3Vjl?tab=code

### Get Required Information Before Deployment

**⚠️ IMPORTANT**: Run these commands BEFORE deploying to save the current version for rollback:

```bash
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-qbZOx3wS3Vjl"
REGION="us-west-2"

# 1. Get current Lambda function version (SAVE THIS FOR ROLLBACK!)
PREVIOUS_VERSION=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Configuration.Version" \
    --output text)
echo "Current version: $PREVIOUS_VERSION"
echo "⚠️  SAVE THIS VERSION NUMBER: $PREVIOUS_VERSION"

# 2. Get current code SHA256 (for verification)
CURRENT_SHA256=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Code.Sha256" \
    --output text)
echo "Current SHA256: $CURRENT_SHA256"

# 3. List all versions (to see what you can rollback to)
aws lambda list-versions-by-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Versions[*].[Version,LastModified]" \
    --output table

# 4. Verify AWS credentials and region
echo "AWS Account: $(aws sts get-caller-identity --query Account --output text)"
echo "AWS Region: $(aws configure get region)"
```

### Deployment Steps

#### Option 1: Deploy via AWS CLI (Recommended)

**Note**: A clean deployment directory is required to ensure only necessary files are included. We use a directory within the Lambda project that gets cleaned up after deployment.

```bash
# Make sure you're in the Lambda directory
LAMBDA_DIR="/Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/query_knowledgebase_resolver"
cd "$LAMBDA_DIR"
source .venv/bin/activate

# Set variables
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-qbZOx3wS3Vjl"
REGION="us-west-2"

# Create a clean deployment directory within the Lambda directory
# This ensures tmp/, .venv/, and test/ are never included
DEPLOY_DIR="$LAMBDA_DIR/deploy-tmp"
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Copy ONLY the files we need (excludes tmp/, .venv/, test/ by design)
cp "$LAMBDA_DIR/index.py" .

# Create a modified requirements.txt with correct path for local package
# The original has ./lib/idp_common_pkg which is relative to Lambda dir
# From deploy-tmp, we need the absolute path: ../../../lib/idp_common_pkg
sed "s|^\./lib/idp_common_pkg|$LAMBDA_DIR/../../../lib/idp_common_pkg|" \
    "$LAMBDA_DIR/requirements.txt" > requirements.txt

# Use .venv/bin/pip explicitly (not global pip)
# Install all dependencies from requirements.txt
# This includes monocle-apptrace from the extra index URL
"$LAMBDA_DIR/.venv/bin/pip" install \
    --requirement requirements.txt \
    --target . \
    --quiet

# Clean up unnecessary files that pip may have created
find . -type d \( -name "__pycache__" -o -name "*.egg-info" -o -name "tests" \) -exec rm -rf {} + 2>/dev/null || true
find . -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true

# Create zip file (tmp/, .venv/, test/ are not in this directory, so they won't be in the zip)
zip -r function.zip . -q

# Deploy to Lambda
aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --zip-file fileb://function.zip

# Wait for update to complete
echo "Waiting for Lambda function to update..."
aws lambda wait function-updated \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION"

# Verify update completed successfully
echo "Checking update status..."
FUNCTION_STATE=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Configuration.State" \
    --output text)
UPDATE_STATUS=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Configuration.LastUpdateStatus" \
    --output text)

if [ "$FUNCTION_STATE" = "Active" ] && [ "$UPDATE_STATUS" = "Successful" ]; then
    echo "✅ Function update completed successfully"
else
    echo "⚠️  Function State: $FUNCTION_STATE, Update Status: $UPDATE_STATUS"
fi

# Get new version
NEW_VERSION=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Configuration.Version" \
    --output text)

# Publish a new version (optional - makes it visible in AWS Console Versions tab)
echo "Publishing new version..."
PUBLISHED_VERSION=$(aws lambda publish-version \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --description "Deployed on $(date +%Y-%m-%d)" \
    --query "Version" \
    --output text)

if [ -n "$PUBLISHED_VERSION" ]; then
    echo "✅ Published version: $PUBLISHED_VERSION"
else
    echo "⚠️  Failed to publish version"
fi

# Clean up deployment directory
cd "$LAMBDA_DIR"
rm -rf "$DEPLOY_DIR"

echo ""
echo "✅ Lambda function updated successfully!"
echo "   Previous version: $PREVIOUS_VERSION"
echo "   New version: $NEW_VERSION"
if [ -n "$PUBLISHED_VERSION" ]; then
    echo "   Published version: $PUBLISHED_VERSION (visible in AWS Console Versions tab)"
fi
echo "   ⚠️  If you need to rollback, use version: $PREVIOUS_VERSION"
```

### Rollback Steps

If the new deployment has issues, rollback to the previous version:

```bash
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-qbZOx3wS3Vjl"
REGION="us-west-2"
PREVIOUS_VERSION="<VERSION_NUMBER>"  # Replace with version saved before deployment

# Get the previous version's code location
CODE_LOCATION=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --qualifier "$PREVIOUS_VERSION" \
    --query "Code.Location" \
    --output text)

# Download previous version code
curl -o /tmp/previous-code.zip "$CODE_LOCATION"

# Deploy previous version
aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --zip-file fileb:///tmp/previous-code.zip

# Wait for update
aws lambda wait function-updated \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION"

# Verify rollback
ROLLBACK_VERSION=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Configuration.Version" \
    --output text)

echo "✅ Rolled back to version $PREVIOUS_VERSION"
echo "   Current active version: $ROLLBACK_VERSION"

# Clean up
rm -f /tmp/previous-code.zip
```

### Verify Deployment

```bash
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-qbZOx3wS3Vjl"
REGION="us-west-2"

# Check update status
aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Configuration.LastUpdateStatus" \
    --output text

# Should return: Successful

# Get current version and SHA256
CURRENT_VERSION=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Configuration.Version" \
    --output text)
CURRENT_SHA256=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Code.Sha256" \
    --output text)

echo "Current version: $CURRENT_VERSION"
echo "Current SHA256: $CURRENT_SHA256"
```

### Understanding Lambda Versions

**Why the Versions tab shows nothing:**

When you use `aws lambda update-function-code`, it updates the `$LATEST` version. The Versions tab in the AWS Console only shows **published versions** (numbered versions like 1, 2, 3, etc.), not `$LATEST`.

- **`$LATEST`** = The editable version you update with `update-function-code` (not shown in Versions tab)
- **Published versions** = Immutable snapshots (shown in Versions tab)

Your deployment is working correctly - you're updating `$LATEST`. If you want to see a version in the Versions tab, you need to publish one.

**To publish a version (optional):**

```bash
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-qbZOx3wS3Vjl"
REGION="us-west-2"

# Publish a new version after updating code
VERSION_ARN=$(aws lambda publish-version \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --description "Deployed on $(date +%Y-%m-%d)" \
    --query "Version" \
    --output text)

echo "✅ Published version: $VERSION_ARN"
```

**Check `$LATEST` version details:**

```bash
# Check the $LATEST version (this is what you updated)
aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --qualifier "\$LATEST" \
    --query "Configuration.[Version,LastModified,CodeSha256]" \
    --output table
```

### Post-Deployment Testing

1. **Test via AppSync GraphQL**:
   - Use the AppSync console or API to test `queryKnowledgeBase` query
   - Verify responses are correct

2. **Monitor CloudWatch Logs**:
   - Check `/aws/lambda/GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-qbZOx3wS3Vjl` log group
   - Verify telemetry is working correctly

3. **Check Trace Files**:
   - If trace files are generated, verify they're created correctly
   - Check for any errors in the traces

## Next Steps

After deployment:
1. ✅ Test with real AppSync GraphQL queries
2. ✅ Monitor CloudWatch logs for telemetry traces
3. ✅ Verify trace files are generated (if applicable)
4. ✅ Monitor function performance and errors
