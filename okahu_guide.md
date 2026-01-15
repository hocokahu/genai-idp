# Okahu Integration Guide

This guide provides instructions for building, deploying, and managing the GenAI IDP sample with Okahu integration.

## Table of Contents

1. [Build, Bootstrap, and Deploy](#1-build-bootstrap-and-deploy)
2. [Update QueryKnowledgeBaseResolverFunction](#2-update-queryknowledgebaseresolverfunction)
3. [Watch Log Streams](#3-watch-log-streams)
4. [User Management](#4-user-management)
5. [Update Okahu Environment Variables](#5-update-okahu-environment-variables)

---

## 1. Build, Bootstrap, and Deploy

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- Node.js 18+ and npm/yarn
- AWS CDK 2.x installed (`npm install -g aws-cdk`)
- Docker (for building Lambda functions)
- Amazon Bedrock access enabled

### Step 1: Bootstrap CDK (First Time Only)

If this is your first CDK deployment in the region, bootstrap CDK:

```bash
# Bootstrap CDK in your region (e.g., ap-south-1, us-west-2)
cdk bootstrap aws://ACCOUNT-ID/REGION

# Example:
cdk bootstrap aws://390041016107/ap-south-1
```

### Step 2: Install Dependencies

```bash
# From repository root
yarn install

# Build all packages (syncs sources to assets)
yarn build:packages
```

### Step 3: Navigate to Sample Directory

```bash
cd samples/sample-bda-lending
```

### Step 4: Deploy

```bash
# Deploy with admin email
yarn deploy --parameters AdminEmail=your-email@example.com

# Example:
yarn deploy --parameters AdminEmail=hoc@okahu.ai
```

### Step 5: Verify Deployment

After deployment completes, you'll see output like:

```
Outputs:
GenAI-IDP-Sample-Pattern1-BdaLending.WebSiteUrl = https://d17oizl1mcff0n.cloudfront.net
Stack ARN: arn:aws:cloudformation:ap-south-1:390041016107:stack/GenAI-IDP-Sample-Pattern1-BdaLending/...
```

---

## 2. Update QueryKnowledgeBaseResolverFunction

### Option A: Update Lambda Code Only (Fastest)

If you only changed the Lambda code (e.g., `index.py` or `requirements.txt`):

#### Step 1: Sync Source to Assets

```bash
# From repository root
cp sources/src/lambda/query_knowledgebase_resolver/requirements.txt \
   packages/@cdklabs/genai-idp/assets/lambdas/query_knowledgebase_resolver/requirements.txt
```

#### Step 2: Create Deployment Package

```bash
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-EsE0CHMkWR0B"
LAMBDA_DIR="packages/@cdklabs/genai-idp/assets/lambdas/query_knowledgebase_resolver"
WORK_DIR="/tmp/lambda-deploy-$$"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Copy Lambda code
cp -r "$(pwd)/../../$LAMBDA_DIR"/* . 2>/dev/null || cp -r "../$LAMBDA_DIR"/* .

# Install dependencies
pip install -r requirements.txt -t . --quiet 2>/dev/null || \
python3 -m pip install -r requirements.txt -t . --quiet

# Clean up
find . -type d \( -name "__pycache__" -o -name "*.egg-info" \) -exec rm -rf {} + 2>/dev/null

# Create zip
zip -r function.zip . -q

# Update Lambda
aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file fileb://function.zip

cd - && rm -rf "$WORK_DIR"
echo "✅ Lambda function updated!"
```

#### Step 3: Verify Update

```bash
# Check update status
aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --query "Configuration.LastUpdateStatus" \
    --output text
```

### Option B: CDK Hotswap (Recommended for CDK Changes)

If you made changes to CDK code or want CDK to track the changes:

```bash
cd samples/sample-bda-lending

# Hotswap deployment (only updates changed Lambda functions)
cdk deploy --hotswap \
    --require-approval never \
    GenAI-IDP-Sample-Pattern1-BdaLending
```

### Option C: Full CDK Deploy

For infrastructure changes or full deployment:

```bash
cd samples/sample-bda-lending

# Make sure assets are synced first
cd ../..
yarn build:packages
cd samples/sample-bda-lending

# Deploy
yarn deploy --parameters AdminEmail=hoc@okahu.ai
```

### Finding the Lambda Function Name

```bash
# Method 1: Search by pattern
aws lambda list-functions \
  --query "Functions[?contains(FunctionName, 'QueryKnowledgeBase')].FunctionName" \
  --output text

# Method 2: Get from CloudFormation
aws cloudformation describe-stack-resources \
  --stack-name GenAI-IDP-Sample-Pattern1-BdaLending \
  --query "StackResources[?ResourceType=='AWS::Lambda::Function' && contains(LogicalResourceId, 'QueryKnowledgeBase')].PhysicalResourceId" \
  --output text
```

---

## 3. Watch Log Streams

### Watch QueryKnowledgeBaseResolverFunction Logs

```bash
# Find and tail logs for QueryKnowledgeBase function
aws logs tail $(aws logs describe-log-groups \
  --region us-west-2 \
  --log-group-name-prefix "GenAI-IDP-Sample-Pattern1" \
  --query 'logGroups[?contains(logGroupName, `QueryKnowledgeBase`)].logGroupName' \
  --output text | head -1) \
  --region us-west-2 \
  --follow \
  --format short
```

### Alternative: Direct Log Group Name

If you know the log group name:

```bash
LOG_GROUP="GenAI-IDP-Sample-Pattern1-BdaLending-EnvApiQueryKnowledgeBaseResolverFunctionLogGroup084E0942-Z5O9YwyFtNXS"

aws logs tail "$LOG_GROUP" \
  --region us-west-2 \
  --follow \
  --format short
```

### Get Log Group from Lambda Function

```bash
FUNCTION_NAME="GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-EsE0CHMkWR0B"

LOG_GROUP=$(aws lambda get-function-configuration \
  --function-name "$FUNCTION_NAME" \
  --query "LoggingConfig.LogGroup" \
  --output text)

aws logs tail "$LOG_GROUP" --follow --format short
```

### Search for Specific Messages

```bash
# Search for monocle-related messages
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern "monocle Monocle setup_monocle ImportError Exception" \
  --start-time $(($(date +%s) - 3600))000 \
  --query "events[*].message" \
  --output text
```

---

## 4. User Management

### Create New User in Cognito

To create a new user, you must first create the user, then set the password. The user must exist before you can set their password.

#### Step 1: Create the User

```bash
aws cognito-idp admin-create-user \
  --user-pool-id us-west-2_iapJu8WgR \
  --username cx@okahu.ai \
  --user-attributes Name=email,Value=cx@okahu.ai \
  --message-action SUPPRESS \
  --region us-west-2
```

#### Step 2: Set the Password (Permanent)

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id us-west-2_iapJu8WgR \
  --username cx@okahu.ai \
  --password 'TempPass123!' \
  --permanent \
  --region us-west-2
```

#### Step 3: Add User to Admin Group (Optional)

To grant admin privileges:

```bash
aws cognito-idp admin-add-user-to-group \
  --user-pool-id us-west-2_iapJu8WgR \
  --username cx@okahu.ai \
  --group-name Admin \
  --region us-west-2
```

#### Complete One-Liner

```bash
# Create user, set password, and add to Admin group
aws cognito-idp admin-create-user \
  --user-pool-id us-west-2_iapJu8WgR \
  --username cx@okahu.ai \
  --user-attributes Name=email,Value=cx@okahu.ai \
  --message-action SUPPRESS \
  --region us-west-2 && \
aws cognito-idp admin-set-user-password \
  --user-pool-id us-west-2_iapJu8WgR \
  --username cx@okahu.ai \
  --password 'TempPass123!' \
  --permanent \
  --region us-west-2 && \
aws cognito-idp admin-add-user-to-group \
  --user-pool-id us-west-2_iapJu8WgR \
  --username cx@okahu.ai \
  --group-name Admin \
  --region us-west-2
```

#### Verify User Creation

```bash
# Check if user exists
aws cognito-idp admin-get-user \
  --user-pool-id us-west-2_iapJu8WgR \
  --username cx@okahu.ai \
  --region us-west-2

# List all users
aws cognito-idp list-users \
  --user-pool-id us-west-2_iapJu8WgR \
  --region us-west-2 \
  --query 'Users[*].{Username:Username,Email:Attributes[?Name==`email`].Value|[0],Status:UserStatus}' \
  --output table
```

### Find User Pool ID

```bash
# List user pools
aws cognito-idp list-user-pools \
  --max-results 10 \
  --query "UserPools[*].[Id,Name]" \
  --output table

# Or get from CloudFormation stack
aws cloudformation describe-stack-resources \
  --stack-name GenAI-IDP-Sample-Pattern1-BdaLending \
  --query "StackResources[?ResourceType=='AWS::Cognito::UserPool'].PhysicalResourceId" \
  --output text
```

### Additional User Management Commands

```bash
# List users in pool
aws cognito-idp list-users \
  --user-pool-id us-west-2_iapJu8WgR \
  --region us-west-2

# Get user details
aws cognito-idp admin-get-user \
  --user-pool-id us-west-2_iapJu8WgR \
  --username cx@okahu.ai \
  --region us-west-2

# Delete user
aws cognito-idp admin-delete-user \
  --user-pool-id us-west-2_iapJu8WgR \
  --username cx@okahu.ai \
  --region us-west-2
```

---

## 5. Update Okahu Environment Variables

The `update-okahu-specific-functions.py` script updates OKAHU environment variables for specific Lambda functions without requiring a rebuild or redeploy.

### Usage

#### Update Default Functions (QueryKnowledgeBaseResolver and ChatWithDocumentResolver)

```bash
# From repository root
python3 update-okahu-specific-functions.py
```

This will automatically find and update:
- Functions containing "QueryKnowledgeBaseResolver"
- Functions containing "ChatWithDocumentResolver"

#### Update Specific Function by Exact Name

```bash
python3 update-okahu-specific-functions.py \
  --exact "GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-EsE0CHMkWR0B"
```

#### Update Functions by Custom Pattern

```bash
python3 update-okahu-specific-functions.py \
  --pattern "QueryKnowledgeBase" "ChatWithDocument"
```

### What the Script Does

1. Finds Lambda functions matching the pattern or exact names
2. Checks if `OKAHU_API_KEY` exists in environment variables
3. Updates `OKAHU_API_KEY` to: `okh_TvXJNYyn_PLj0x0qXRcyafFXRydgA`
4. Adds/updates `OKAHU_INGESTION_ENDPOINT`: `https://ingest.stage.okahu.ai/api/v1/trace/ingest`
5. Changes take effect immediately (no restart needed)

### Configuration

To modify the API key or endpoint, edit the script:

```python
# Configuration (lines 16-18)
NEW_OKAHU_API_KEY = "okh_TvXJNYyn_PLj0x0qXRcyafFXRydgA"
OKAHU_INGESTION_ENDPOINT = "https://ingest.stage.okahu.ai/api/v1/trace/ingest"
```

### Example Output

```
🔍 Finding Lambda functions...

Searching for functions matching: QueryKnowledgeBaseResolver
  Processing: GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-EsE0CHMkWR0B
    ✅ Found OKAHU_API_KEY, updating...
    ✅ Successfully updated GenAI-IDP-Sample-Pattern1-EnvApiQueryKnowledgeBase-EsE0CHMkWR0B

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Summary:
  ✅ Updated: 1 function(s)
  ⚠️  Not found: 0 pattern(s)
  ❌ Errors:  0 function(s)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ️  Note: No restart needed! Changes take effect immediately for new invocations.
```

---

## Quick Reference

### Common Commands

```bash
# Build packages
yarn build:packages

# Deploy stack
cd samples/sample-bda-lending
yarn deploy --parameters AdminEmail=hoc@okahu.ai

# Find Lambda function
aws lambda list-functions --query "Functions[?contains(FunctionName, 'QueryKnowledgeBase')].FunctionName" --output text

# Get log group
aws lambda get-function-configuration --function-name "FUNCTION_NAME" --query "LoggingConfig.LogGroup" --output text

# Tail logs
aws logs tail "LOG_GROUP_NAME" --follow --format short

# Update Okahu env vars
python3 update-okahu-specific-functions.py
```

### Troubleshooting

#### CloudFront Policy Conflict

If you get a CloudFront ResponseHeadersPolicy conflict:

```bash
# Find and delete conflicting policies
aws cloudfront list-response-headers-policies --output json | \
  jq -r '.ResponseHeadersPolicyList.Items[] | select(.Type != "managed") | [.ResponseHeadersPolicy.Id, .ResponseHeadersPolicy.ResponseHeadersPolicyConfig.Name] | @tsv'

# Delete specific policy
aws cloudfront delete-response-headers-policy \
  --id "POLICY_ID" \
  --if-match $(aws cloudfront get-response-headers-policy --id "POLICY_ID" --query "ETag" --output text)
```

#### IAM Role Conflict

If you get an IAM role conflict:

```bash
# Find the role
aws iam get-role --role-name "ROLE_NAME"

# Delete inline policies
aws iam list-role-policies --role-name "ROLE_NAME" --query "PolicyNames[]" --output text | \
  tr '\t' '\n' | xargs -I {} aws iam delete-role-policy --role-name "ROLE_NAME" --policy-name {}

# Detach managed policies and delete role
aws iam list-attached-role-policies --role-name "ROLE_NAME" --query "AttachedPolicies[*].PolicyArn" --output text | \
  tr '\t' '\n' | xargs -I {} aws iam detach-role-policy --role-name "ROLE_NAME" --policy-arn {}
aws iam delete-role --role-name "ROLE_NAME"
```

---

## Notes

- **Region**: Make sure to use the correct AWS region in all commands (default shown: `us-west-2`, but your deployment may be in `ap-south-1`)
- **No Code Changes**: The `update-okahu-specific-functions.py` script only updates environment variables, no code changes needed
- **Immediate Effect**: Environment variable changes take effect immediately for new Lambda invocations
- **Log Retention**: Log groups are configured with retention policies, check CloudFormation for retention settings
