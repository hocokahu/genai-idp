# Agent Processor Lambda Function - Test Documentation

## AWS Lambda Function Name

The deployed AWS Lambda function name for `agent_processor` is:

**`GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY`**

## CloudFormation Deployment

The function is deployed via CloudFormation stack:

**Stack Name**: `GenAI-IDP-Sample-Pattern1-BdaLending`

**CloudFormation Logical Resource ID**: `EnvApiAgentAnalyticsAgentProcessor380F754E`

**Physical Resource ID (Lambda Function Name)**: `GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY`

## Verification

### Confirmed via AWS CLI

The function was identified by checking:

1. **CloudFormation Stack Resources**: Verified via `aws cloudformation describe-stack-resources` that the logical resource `EnvApiAgentAnalyticsAgentProcessor380F754E` maps to the physical Lambda function name
2. **Environment Variables**: The function has `AGENT_TABLE` environment variable, which is used by the agent_processor code
3. **Function Reference**: Another Lambda function (`GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-98lQiFqr5tdY`) references this function as `AGENT_PROCESSOR_FUNCTION` in its environment variables
4. **Runtime**: Python 3.12 with handler `index.handler` (matches agent_processor implementation)

### Function Details

- **Function Name**: `GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY`
- **Runtime**: `python3.12`
- **Handler**: `index.handler`
- **Last Modified**: `2026-01-07T18:48:25.000+0000`
- **CloudFormation Stack**: `GenAI-IDP-Sample-Pattern1-BdaLending`
- **Logical Resource ID**: `EnvApiAgentAnalyticsAgentProcessor380F754E`

### Key Environment Variables

- `AGENT_TABLE`: `GenAI-IDP-Sample-Pattern1-BdaLending-EnvApiAgentAnalyticsAgentTableC2F72206-GWD5MYOJ4C2H`
- `APPSYNC_API_URL`: AppSync GraphQL endpoint
- `LOG_LEVEL`: `INFO`
- `STRANDS_LOG_LEVEL`: `INFO`
- Additional configuration for analytics, monitoring, and document analysis

## Note on Other Functions

The following functions are **NOT** the agent_processor:

- `GenAI-IDP-Sample-Pattern1-DiscoveryProcessor620EAA-3imQwO5aOFuY` - This is the **Discovery Processor** (has `DISCOVERY_BUCKET`, `DISCOVERY_TRACKING_TABLE` environment variables)
- `GenAI-IDP-Sample-Pattern1-Pattern1QueueProcessorD7-U86mQErge3GO` - This is the **Queue Processor** (has `STATE_MACHINE_ARN`, `WORKING_BUCKET`, `TRACKING_TABLE` environment variables)

## CLI Commands to Verify

### Verify via CloudFormation Stack

```bash
# List agent-related resources in the CloudFormation stack
aws cloudformation describe-stack-resources \
  --stack-name GenAI-IDP-Sample-Pattern1-BdaLending \
  --query 'StackResources[?contains(LogicalResourceId, `Agent`) && ResourceType==`AWS::Lambda::Function`].{LogicalId:LogicalResourceId, PhysicalId:PhysicalResourceId}' \
  --output table

# Get the specific agent processor function
aws cloudformation describe-stack-resources \
  --stack-name GenAI-IDP-Sample-Pattern1-BdaLending \
  --logical-resource-id EnvApiAgentAnalyticsAgentProcessor380F754E \
  --query 'StackResources[0].{LogicalId:LogicalResourceId, PhysicalId:PhysicalResourceId, Type:ResourceType}' \
  --output json
```

### Verify via Lambda Function

```bash
# List the function details
aws lambda get-function-configuration \
  --function-name GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY \
  --query '{FunctionName:FunctionName, Handler:Handler, Runtime:Runtime, Environment:Environment.Variables}' \
  --output json

# Check if AGENT_TABLE is present
aws lambda get-function-configuration \
  --function-name GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY \
  --query 'Environment.Variables.AGENT_TABLE' \
  --output text
```

## Local Testing Guide

This directory contains test files for locally testing the `agent_processor` Lambda function.

### Setup Instructions

#### Step 1: Create Virtual Environment

```bash
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/agent_processor
python3 -m venv .venv
source .venv/bin/activate
```

#### Step 2: Install Dependencies

```bash
# Install monocle-apptrace from JFrog Artifactory
pip install --extra-index-url https://okahu.jfrog.io/artifactory/api/pypi/okahu-patch-pypi/simple monocle-apptrace==0.7.2b2

# Install other dependencies
pip install requests aws-requests-auth

# Install idp_common_pkg with [agents] extra (this installs strands and other agent dependencies)
pip install -e "../../../lib/idp_common_pkg[agents]"
```

**Important**: The `[agents]` extra is required to install the `strands` dependency needed by the agent processor.

#### Step 3: Configure Environment Variables

Edit `test/.env` with your actual values. The file supports both formats:
- `KEY=VALUE` (standard format)
- `export KEY=VALUE` (shell export format)

Required variables:
- `AGENT_TABLE`: DynamoDB table name for agent jobs
- `APPSYNC_API_URL`: AppSync GraphQL endpoint URL
- `AWS_REGION`: Your AWS region (e.g., "us-west-2")
- `LOG_LEVEL`: Logging level (e.g., "INFO", "DEBUG")
- `STRANDS_LOG_LEVEL`: Strands framework log level (e.g., "INFO", "DEBUG")

Example `test/.env`:
```bash
export AGENT_TABLE=GenAI-IDP-Sample-Pattern1-BdaLending-EnvApiAgentAnalyticsAgentTableC2F72206-GWD5MYOJ4C2H
export APPSYNC_API_URL=https://hp5b3jnckbgqtgmshdqs2q6cxu.appsync-api.us-west-2.amazonaws.com/graphql
export AWS_REGION=us-west-2
export LOG_LEVEL=INFO
export STRANDS_LOG_LEVEL=INFO
```

#### Step 4: Run the Test

The test script will automatically create a test job in DynamoDB before calling the handler.

**Basic Execution:**

```bash
# Make sure you're in the Lambda directory
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/agent_processor

# Activate virtual environment (if not already active)
source .venv/bin/activate

# Run the test (creates test job automatically)
python test/test_local.py
```

**With Custom Event:**

```bash
# Use a custom event file
python test/test_local.py --event test/event.json
```

**What the test script does:**
1. Loads environment variables from `test/.env`
2. Imports the Lambda function module (tests monocle telemetry setup)
3. **Creates a test job in DynamoDB** with:
   - `PK`: `agent#{userId}` (from event)
   - `SK`: `{jobId}` (from event)
   - `query`: "What is the total revenue?"
   - `agentIds`: `["Analytics-Agent-v1"]`
   - `status`: "PENDING"
4. Calls the handler with the test event
5. Monocle automatically generates trace files in `.monocle/` folder

**Example Output:**

```
======================================================================
Testing agent_processor Lambda Function
======================================================================
Lambda directory: /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/agent_processor
...

✅ Successfully imported index module
✅ setup_monocle_telemetry executed without errors
...

Creating test job in DynamoDB...
✅ Created test job in DynamoDB:
   PK: agent#test-user-123
   SK: test-job-456
   Query: What is the total revenue?
   AgentIds: ["Analytics-Agent-v1"]

Calling handler...
======================================================================
✅ SUCCESS! Handler executed successfully
======================================================================
...

✅ All tests passed!
======================================================================

Note: Check .monocle/ folder for trace files (may take a few seconds to appear)
```

**Expected Output:**
- ✅ Import and telemetry setup success
- ✅ Test job created in DynamoDB
- ✅ Handler execution with agent processing
- ✅ Trace files generated in `.monocle/` folder

### What This Tests

The test script verifies:

1. ✅ **Import Test**: Module imports successfully, including `setup_monocle_telemetry`
2. ✅ **Handler Test**: The Lambda handler function works correctly
3. ✅ **Environment Variables**: Required environment variables are set

### How It Works

1. **Direct Python Import**: The test script imports `index.py` directly as a Python module
   - When Python imports the module, it executes all module-level code
   - This includes the `setup_monocle_telemetry` call
   - Any errors will be caught immediately

2. **Environment Variables**: Loads from `test/.env` before importing
   - Ensures all required env vars are set
   - Matches the Lambda runtime environment

3. **Handler Execution**: Calls `index.handler(event, context)` directly
   - Uses a mock Lambda context
   - Uses a sample event with `userId` and `jobId`
   - Tests the full handler flow

**Note**: The test script automatically creates a test job in DynamoDB before calling the handler. You don't need to manually create the job - the script handles it for you.

### Test Output

The test will show:
- ✅ Import success/failure
- ✅ Telemetry setup success/failure
- ✅ Test job creation in DynamoDB
- ✅ Handler execution results
- ✅ Full error traces if anything fails
- ✅ Note about trace files in `.monocle/` folder

**Trace Files:**
After the test completes, check the `.monocle/` folder for trace files. Monocle automatically generates trace files when spans are created and exported. The files are named like:
- `monocle_trace_aws-genai-idp_{trace_id}_{timestamp}.json`

Note: Trace files may take a few seconds to appear as Monocle batches spans before writing them.

### Troubleshooting

#### Import Errors

**Error: `ModuleNotFoundError: No module named 'idp_common'`**
- Make sure you're running from `sources/src/lambda/agent_processor/`
- Check that `sources/lib/idp_common_pkg` exists
- Install it with the `[agents]` extra: `pip install -e "../../../lib/idp_common_pkg[agents]"`

**Error: `ModuleNotFoundError: No module named 'strands'`**
- This means `idp_common_pkg` was installed without the `[agents]` extra
- Reinstall with: `pip install -e "../../../lib/idp_common_pkg[agents]"`
- The `[agents]` extra installs `strands` and other required agent dependencies

**Error: `ModuleNotFoundError: No module named 'monocle_apptrace'`**
- Install it from JFrog Artifactory:
  ```bash
  pip install --extra-index-url https://okahu.jfrog.io/artifactory/api/pypi/okahu-patch-pypi/simple monocle-apptrace==0.7.2b2
  ```
- Or install from requirements.txt: `pip install -r requirements.txt`

#### AWS Credentials

The test uses your default AWS credentials:
```bash
aws configure
```

#### Missing Environment Variables

Update values in `test/.env`:
```bash
# Required variables
AGENT_TABLE=your-table-name
APPSYNC_API_URL=https://your-api.appsync-api.region.amazonaws.com/graphql
AWS_REGION=us-west-2
LOG_LEVEL=INFO
STRANDS_LOG_LEVEL=INFO
```

#### DynamoDB Job Not Found

If you get "Job not found" errors:
1. **Check AWS credentials**: Make sure your AWS credentials are configured
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

2. **Check AGENT_TABLE environment variable**: Verify it's set in `test/.env`
   ```bash
   grep AGENT_TABLE test/.env
   ```

3. **Check DynamoDB permissions**: Ensure your AWS credentials have permission to write to the table
   ```bash
   # Test write access
   aws dynamodb put-item \
     --table-name "$(grep AGENT_TABLE test/.env | cut -d'=' -f2)" \
     --item '{"PK":{"S":"agent#test"}, "SK":{"S":"test"}}' \
     --region us-west-2
   ```

4. **Verify the test job was created**: The script should show "✅ Created test job in DynamoDB" - if not, check the error message

**Note**: The test script automatically creates the job, so this error usually indicates:
- AWS credentials not configured
- Missing or incorrect `AGENT_TABLE` environment variable
- Insufficient DynamoDB permissions

## Deploying to AWS Lambda

After local testing passes, deploy the Lambda function to AWS.

### Target Lambda Function

- **Function Name**: `GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY`
- **Region**: `us-west-2`
- **CloudFormation Stack**: `GenAI-IDP-Sample-Pattern1-BdaLending`
- **Console URL**: https://us-west-2.console.aws.amazon.com/lambda/home?region=us-west-2#/functions/GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY?tab=code

### Get Required Information Before Deployment

**⚠️ IMPORTANT**: The deployment script automatically saves the current version for rollback, but you can also check manually:

```bash
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY"
REGION="us-west-2"

# Get current Lambda function version
PREVIOUS_VERSION=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Configuration.Version" \
    --output text)
echo "Current version: $PREVIOUS_VERSION"

# List all versions
aws lambda list-versions-by-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query "Versions[*].[Version,LastModified]" \
    --output table

# Verify AWS credentials and region
echo "AWS Account: $(aws sts get-caller-identity --query Account --output text)"
echo "AWS Region: $(aws configure get region)"
```

### Deployment Steps

#### Option 1: Deploy via Script (Recommended)

```bash
# Make sure you're in the Lambda directory
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/agent_processor

# Make the script executable (if not already)
chmod +x test/deploy.sh

# Deploy
./test/deploy.sh deploy

# Or just run (deploy is the default)
./test/deploy.sh
```

The script will:
1. Save the current version for rollback
2. Create a clean deployment package
3. Install dependencies
4. Deploy to Lambda
5. Wait for update to complete
6. Publish a new version
7. Clean up temporary files

#### Option 2: Deploy via AWS CLI (Manual)

```bash
# Make sure you're in the Lambda directory
LAMBDA_DIR="/Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/agent_processor"
cd "$LAMBDA_DIR"
source .venv/bin/activate

# Set variables
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY"
REGION="us-west-2"

# Create a clean deployment directory
DEPLOY_DIR="$LAMBDA_DIR/deploy-tmp"
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Copy ONLY the files we need
cp "$LAMBDA_DIR/index.py" .

# Create a modified requirements.txt with correct path for local package
sed "s|^\./lib/idp_common_pkg|$LAMBDA_DIR/../../../lib/idp_common_pkg|" \
    "$LAMBDA_DIR/requirements.txt" > requirements.txt

# Install all dependencies
"$LAMBDA_DIR/.venv/bin/pip" install \
    --requirement requirements.txt \
    --target . \
    --quiet

# Clean up unnecessary files
find . -type d \( -name "__pycache__" -o -name "*.egg-info" -o -name "tests" \) -exec rm -rf {} + 2>/dev/null || true
find . -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true

# Create zip file
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

# Publish a new version (optional)
echo "Publishing new version..."
PUBLISHED_VERSION=$(aws lambda publish-version \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --description "Deployed on $(date +%Y-%m-%d)" \
    --query "Version" \
    --output text)

if [ -n "$PUBLISHED_VERSION" ]; then
    echo "✅ Published version: $PUBLISHED_VERSION"
fi

# Clean up deployment directory
cd "$LAMBDA_DIR"
rm -rf "$DEPLOY_DIR"

echo ""
echo "✅ Lambda function updated successfully!"
echo "   New version: $NEW_VERSION"
if [ -n "$PUBLISHED_VERSION" ]; then
    echo "   Published version: $PUBLISHED_VERSION"
fi
```

### Rollback Steps

#### Option 1: Rollback via Script (Recommended)

```bash
# Make sure you're in the Lambda directory
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/agent_processor

# Rollback to previous version
./test/deploy.sh rollback
```

The script will:
1. Read the saved previous version
2. Download the previous version's code
3. Deploy it to Lambda
4. Wait for update to complete
5. Verify rollback

#### Option 2: Rollback via AWS CLI (Manual)

```bash
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY"
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
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY"
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

Your deployment is working correctly - you're updating `$LATEST`. If you want to see a version in the Versions tab, you need to publish one (the script does this automatically).

**Check `$LATEST` version details:**

```bash
aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --qualifier "\$LATEST" \
    --query "Configuration.[Version,LastModified,CodeSha256]" \
    --output table
```

### Post-Deployment Testing

1. **Test via Lambda Console**:
   - Use the Lambda console test feature
   - Create a test event with `userId` and `jobId`
   - Verify responses are correct

2. **Monitor CloudWatch Logs**:
   - Check `/aws/lambda/GenAI-IDP-Sample-Pattern1-EnvApiAgentAnalyticsAgen-TzRWPIbxz3EY` log group
   - Verify function is working correctly

3. **Test via AppSync**:
   - Trigger agent jobs via AppSync GraphQL API
   - Verify job processing completes successfully

## File Structure

```
agent_processor/
├── index.py              # Lambda function
├── requirements.txt      # Dependencies
├── .venv/               # Virtual environment (not in git)
├── deploy-tmp/          # Temporary deployment directory (created during deploy)
└── test/
    ├── test_local.py    # Main test script
    ├── event.json        # Sample Lambda event
    ├── deploy.sh         # Deployment and rollback script
    ├── .env              # Environment variables (not in git)
    ├── .previous_version # Saved version for rollback (created during deploy)
    └── README.md         # This file
```
