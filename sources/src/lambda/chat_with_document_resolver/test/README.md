# Chat With Document Resolver - Test and Deployment

This directory contains testing and deployment scripts for the `chat_with_document_resolver` Lambda function.

## Files

- **`test_local.py`** - Local testing script that simulates the Lambda handler with mock AppSync GraphQL events
- **`deploy.sh`** - Deployment script to update the Lambda function code in AWS
- **`event.json`** - Example AppSync GraphQL event for testing
- **`.env.template`** - Template for environment variables (copy to `.env` and fill in values)

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Python 3.12** (or compatible version)
3. **pip** for installing dependencies
4. **Access to the Lambda function**: `GenAI-IDP-Sample-Pattern1-EnvApiChatWithDocumentRe-bc5jrUKCSW23` in region `us-west-2`

## Setup

### Step 1: Create Virtual Environment

```bash
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/chat_with_document_resolver
python3 -m venv .venv
source .venv/bin/activate
```

### Step 2: Install Dependencies

```bash
# Install monocle-apptrace from JFrog Artifactory
pip install --extra-index-url https://okahu.jfrog.io/artifactory/api/pypi/okahu-patch-pypi/simple monocle-apptrace==0.7.2b2

# Install idp_common_pkg (no [agents] extra needed for chat_with_document_resolver)
pip install -e "../../../lib/idp_common_pkg"
```

**Important**: Unlike `agent_processor`, `chat_with_document_resolver` does NOT need the `[agents]` extra - it only needs the base `idp_common_pkg` package.

### Step 3: Configure Environment Variables

Copy the template and fill in your values:

```bash
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/chat_with_document_resolver/test
cp .env.template .env
# Edit .env with your actual values
```

The file supports both formats:
- `KEY=VALUE` (standard format)
- `export KEY=VALUE` (shell export format)

Required variables:
- `OUTPUT_BUCKET`: S3 bucket containing processed documents
- `TRACKING_TABLE_NAME`: DynamoDB table for document tracking
- `CONFIGURATION_TABLE_NAME`: DynamoDB table for configuration
- `AWS_REGION`: Your AWS region (e.g., "us-west-2")
- `LOG_LEVEL`: Logging level (e.g., "INFO", "DEBUG")

## Local Testing

### Run Local Test

```bash
# Make sure you're in the Lambda directory
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/chat_with_document_resolver

# Activate virtual environment (if not already active)
source .venv/bin/activate

# Run the test
python test/test_local.py
```

### Test with Custom Event

```bash
python test/test_local.py --event test/event.json
```

### What the Test Does

1. Loads environment variables from `test/.env`
2. Imports the Lambda handler (`index.py`)
3. Tests the handler with a mock AppSync GraphQL event
4. Displays the response or any errors

**Note**: The test may fail if:
- The document doesn't exist in S3 (`OUTPUT_BUCKET`)
- The document doesn't exist in DynamoDB (`TRACKING_TABLE_NAME`)
- Required environment variables are missing
- AWS credentials are not configured

## Deployment

### Prerequisites

Before deploying, make sure you've completed the setup steps above. The virtual environment and dependencies are needed for local testing, but the deployment script creates its own package with Linux-compatible dependencies.

### Quick Deploy

```bash
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/chat_with_document_resolver/test
./deploy.sh
```

### What the Deployment Script Does

1. **Saves current version** for potential rollback
2. **Verifies AWS credentials** and account
3. **Creates deployment package**:
   - Copies `index.py`
   - Installs PyPI dependencies for Linux platform (manylinux2014_x86_64)
   - Copies local `idp_common_pkg` from `sources/lib/idp_common_pkg`
   - Creates a zip file
4. **Deploys to Lambda**:
   - Updates function code
   - Waits for update to complete
   - Publishes a new version
5. **Cleans up** temporary files

### Deployment Details

- **Function Name**: `GenAI-IDP-Sample-Pattern1-EnvApiChatWithDocumentRe-bc5jrUKCSW23`
- **Region**: `us-west-2`
- **Package Path**: The script automatically finds the Lambda directory and `lib/idp_common_pkg`

## Rollback

If you need to rollback to the previous version:

```bash
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/chat_with_document_resolver/test
./deploy.sh rollback
```

The script will:
1. Read the saved previous version from `.previous_version` file
2. Download the previous version's code
3. Deploy it to the Lambda function

**Note**: Rollback only works if you've deployed at least once (to create the `.previous_version` file).

## Troubleshooting

### Deployment Fails

1. **Check AWS credentials**:
   ```bash
   aws sts get-caller-identity
   ```

2. **Verify function exists**:
   ```bash
   aws lambda get-function \
     --function-name GenAI-IDP-Sample-Pattern1-EnvApiChatWithDocumentRe-bc5jrUKCSW23 \
     --region us-west-2
   ```

3. **Check permissions**: Ensure your AWS credentials have `lambda:UpdateFunctionCode` permission

### Local Test Fails

1. **Check virtual environment**: Make sure you've created and activated the virtual environment
   ```bash
   cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/chat_with_document_resolver
   source .venv/bin/activate
   ```

2. **Check dependencies**: Make sure you've installed all dependencies
   ```bash
   pip install --extra-index-url https://okahu.jfrog.io/artifactory/api/pypi/okahu-patch-pypi/simple monocle-apptrace==0.7.2b2
   pip install -e "../../../lib/idp_common_pkg"
   ```

3. **Check environment variables**: Ensure `.env` file exists and has all required variables

4. **Check Python path**: The script should automatically add `lib/idp_common_pkg` to the path

#### Import Errors

**Error: `ModuleNotFoundError: No module named 'idp_common'`**
- Make sure you're running from `sources/src/lambda/chat_with_document_resolver/`
- Check that `sources/lib/idp_common_pkg` exists
- Install it with: `pip install -e "../../../lib/idp_common_pkg"`

**Error: `ModuleNotFoundError: No module named 'monocle_apptrace'`**
- Install it from JFrog Artifactory:
  ```bash
  pip install --extra-index-url https://okahu.jfrog.io/artifactory/api/pypi/okahu-patch-pypi/simple monocle-apptrace==0.7.2b2
  ```

#### AWS Credentials

The test uses your default AWS credentials:
```bash
aws configure
aws sts get-caller-identity
```

### Path Issues

The scripts use these path calculations:
- **Lambda directory**: `test/` → parent = `chat_with_document_resolver/`
- **Lib directory**: `sources/src/lambda/chat_with_document_resolver/` → up 3 levels → `sources/lib/idp_common_pkg`

If you encounter path errors, verify:
```bash
ls -la /Users/quanghoc/Documents/GitHub/genai-idp/sources/lib/idp_common_pkg
```

## Lambda Function Details

### Handler
- **File**: `index.py`
- **Function**: `handler(event, context)`
- **Event Format**: AppSync GraphQL resolver event with `arguments` containing:
  - `s3Uri`: S3 object key (e.g., `"lending_package.pdf"`)
  - `prompt`: User's question
  - `history`: Conversation history (JSON array)
  - `modelId`: Bedrock model ID (e.g., `"us.amazon.nova-pro-v1:0"`)

### Required Environment Variables

- `OUTPUT_BUCKET` - S3 bucket containing processed documents
- `TRACKING_TABLE_NAME` - DynamoDB table for document tracking
- `CONFIGURATION_TABLE_NAME` - DynamoDB table for configuration
- `AWS_REGION` - AWS region (default: `us-west-2`)
- `LOG_LEVEL` - Logging level (default: `INFO`)

### Optional Environment Variables

- `GUARDRAIL_ID_AND_VERSION` - Bedrock guardrail configuration
- `KB_ACCOUNT_ID`, `KB_ID`, `KB_REGION` - Knowledge base configuration
- `MODEL_ID` - Default model ID
- `MONOCLE_*` - Monocle tracing configuration
- `OKAHU_API_KEY` - Okahu API key

## Example Event

See `event.json` for an example AppSync GraphQL event:

```json
{
  "arguments": {
    "s3Uri": "lending_package.pdf",
    "prompt": "What is the total amount?",
    "history": [],
    "modelId": "us.amazon.nova-pro-v1:0"
  }
}
```

## Complete Workflow Summary

Here's the complete workflow from setup to deployment:

### Initial Setup (One-time)

```bash
# 1. Navigate to Lambda directory
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/chat_with_document_resolver

# 2. Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# 3. Install dependencies
pip install --extra-index-url https://okahu.jfrog.io/artifactory/api/pypi/okahu-patch-pypi/simple monocle-apptrace==0.7.2b2
pip install -e "../../../lib/idp_common_pkg"

# 4. Configure environment variables
cd test
cp .env.template .env
# Edit .env with your actual values
```

### Local Testing (Before Deployment)

```bash
# 1. Navigate to Lambda directory
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/chat_with_document_resolver

# 2. Activate virtual environment
source .venv/bin/activate

# 3. Run test
python test/test_local.py
```

### Deployment

```bash
# 1. Navigate to test directory
cd /Users/quanghoc/Documents/GitHub/genai-idp/sources/src/lambda/chat_with_document_resolver/test

# 2. Verify AWS credentials
aws sts get-caller-identity

# 3. Deploy
./deploy.sh
```

**Note**: The deployment script handles creating the deployment package with Linux-compatible dependencies automatically. You don't need the virtual environment active for deployment - it's only needed for local testing.

## Related Files

- **Lambda Code**: `../index.py`
- **Requirements**: `../requirements.txt`
- **CDK Construct**: `packages/@cdklabs/genai-idp/src/processing-environment-api/functions/chat-with-document-resolver-function.ts`
