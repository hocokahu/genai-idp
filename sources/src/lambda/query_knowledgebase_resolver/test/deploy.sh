#!/bin/bash
# Deployment and rollback script for query_knowledgebase_resolver Lambda function

set -e  # Exit on error

# Configuration
# Auto-detect function name if not set, or use provided one
FUNCTION_NAME="${FUNCTION_NAME:-$(aws lambda list-functions --query "Functions[?contains(FunctionName, 'QueryKnowledgeBase')].FunctionName" --output text | head -1)}"
REGION="${REGION:-us-west-2}"
LAMBDA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_DIR="$LAMBDA_DIR/deploy-tmp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get current version
get_current_version() {
    aws lambda get-function \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION" \
        --query "Configuration.Version" \
        --output text 2>/dev/null || echo "unknown"
}

# Function to save current version for rollback
save_version_for_rollback() {
    local version_file="$LAMBDA_DIR/test/.previous_version"
    local current_version=$(get_current_version)
    echo "$current_version" > "$version_file"
    print_info "Saved current version for rollback: $current_version"
    echo "$current_version"
}

# Function to deploy
deploy() {
    print_info "Starting deployment..."
    
    # Validate function name
    if [ -z "$FUNCTION_NAME" ] || [ "$FUNCTION_NAME" = "None" ]; then
        print_error "Could not find QueryKnowledgeBase Lambda function"
        print_error "Please set FUNCTION_NAME environment variable or ensure function exists"
        exit 1
    fi
    
    # Save current version before deployment
    PREVIOUS_VERSION=$(save_version_for_rollback)
    
    # Verify AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        print_error "AWS credentials not configured. Run 'aws configure'"
        exit 1
    fi
    
    print_info "AWS Account: $(aws sts get-caller-identity --query Account --output text)"
    print_info "AWS Region: $REGION"
    print_info "Function Name: $FUNCTION_NAME"
    print_info "Previous Version: $PREVIOUS_VERSION"
    echo
    
    # Create clean deployment directory
    print_info "Creating deployment package..."
    rm -rf "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_DIR"
    cd "$DEPLOY_DIR"
    
    # Copy only necessary files
    cp "$LAMBDA_DIR/index.py" .
    
    if [ ! -f "$LAMBDA_DIR/requirements.txt" ]; then
        print_error "requirements.txt not found in $LAMBDA_DIR"
        exit 1
    fi
    
    LOCAL_PKG_PATH="$LAMBDA_DIR/../../../lib/idp_common_pkg"
    
    # Step 1: Install PyPI dependencies with Linux platform flags
    # Create a temp requirements file with only PyPI packages (exclude local package and extra-index-url)
    print_info "Installing PyPI dependencies for Linux platform..."
    grep -v "^\./lib/idp_common_pkg" "$LAMBDA_DIR/requirements.txt" | \
        grep -v "^--extra-index-url" > requirements_pypi.txt || true
    
    # Extract extra-index-url if present
    EXTRA_INDEX=$(grep "^--extra-index-url" "$LAMBDA_DIR/requirements.txt" | head -1 | sed 's/^--extra-index-url //' || echo "")
    
    if [ -n "$EXTRA_INDEX" ] && [ -s requirements_pypi.txt ]; then
        print_info "Installing with extra-index-url: $EXTRA_INDEX"
        pip install \
            --extra-index-url "$EXTRA_INDEX" \
            --requirement requirements_pypi.txt \
            --target . \
            --platform manylinux2014_x86_64 \
            --only-binary=:all: \
            --python-version 3.12 \
            --implementation cp \
            --quiet
    elif [ -s requirements_pypi.txt ]; then
        pip install \
            --requirement requirements_pypi.txt \
            --target . \
            --platform manylinux2014_x86_64 \
            --only-binary=:all: \
            --python-version 3.12 \
            --implementation cp \
            --quiet
    fi
    
    # Step 2: Copy the local idp_common_pkg package (pure Python, no compilation needed)
    print_info "Copying local idp_common_pkg package (pure Python)..."
    if [ -d "$LOCAL_PKG_PATH/idp_common" ]; then
        # Copy the entire idp_common package
        cp -r "$LOCAL_PKG_PATH/idp_common" . 2>/dev/null || {
            print_error "Failed to copy idp_common package from $LOCAL_PKG_PATH"
            exit 1
        }
        print_info "✅ Copied idp_common package"
    else
        print_error "idp_common directory not found at $LOCAL_PKG_PATH"
        exit 1
    fi
    
    # Clean up unnecessary files
    find . -type d \( -name "__pycache__" -o -name "*.egg-info" -o -name "tests" \) -exec rm -rf {} + 2>/dev/null || true
    find . -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true
    
    # Create zip file
    print_info "Creating deployment package..."
    zip -r function.zip . -q
    
    # Deploy to Lambda
    print_info "Deploying to Lambda..."
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION" \
        --zip-file fileb://function.zip
    
    # Wait for update to complete
    print_info "Waiting for Lambda function to update..."
    aws lambda wait function-updated \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION"
    
    # Verify update
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
        print_info "Function update completed successfully"
    else
        print_warn "Function State: $FUNCTION_STATE, Update Status: $UPDATE_STATUS"
    fi
    
    # Get new version
    NEW_VERSION=$(get_current_version)
    
    # Publish a new version (optional)
    print_info "Publishing new version..."
    PUBLISHED_VERSION=$(aws lambda publish-version \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION" \
        --description "Deployed on $(date +%Y-%m-%d)" \
        --query "Version" \
        --output text 2>/dev/null || echo "")
    
    # Clean up
    cd "$LAMBDA_DIR"
    rm -rf "$DEPLOY_DIR"
    
    echo
    print_info "✅ Deployment completed successfully!"
    echo "   Previous version: $PREVIOUS_VERSION"
    echo "   New version: $NEW_VERSION"
    if [ -n "$PUBLISHED_VERSION" ]; then
        echo "   Published version: $PUBLISHED_VERSION"
    fi
    echo "   ⚠️  If you need to rollback, run: $0 rollback"
}

# Function to rollback
rollback() {
    print_info "Starting rollback..."
    
    # Get previous version from file
    local version_file="$LAMBDA_DIR/test/.previous_version"
    if [ ! -f "$version_file" ]; then
        print_error "Previous version file not found: $version_file"
        print_error "Cannot rollback automatically. Please specify version manually."
        exit 1
    fi
    
    PREVIOUS_VERSION=$(cat "$version_file")
    print_info "Rolling back to version: $PREVIOUS_VERSION"
    
    # Get the previous version's code location
    CODE_LOCATION=$(aws lambda get-function \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION" \
        --qualifier "$PREVIOUS_VERSION" \
        --query "Code.Location" \
        --output text)
    
    if [ -z "$CODE_LOCATION" ]; then
        print_error "Could not retrieve code location for version $PREVIOUS_VERSION"
        exit 1
    fi
    
    # Download previous version code
    print_info "Downloading previous version code..."
    curl -o /tmp/previous-code.zip "$CODE_LOCATION"
    
    # Deploy previous version
    print_info "Deploying previous version..."
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION" \
        --zip-file fileb:///tmp/previous-code.zip
    
    # Wait for update
    print_info "Waiting for Lambda function to update..."
    aws lambda wait function-updated \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION"
    
    # Verify rollback
    ROLLBACK_VERSION=$(get_current_version)
    
    # Clean up
    rm -f /tmp/previous-code.zip
    
    echo
    print_info "✅ Rolled back to version $PREVIOUS_VERSION"
    echo "   Current active version: $ROLLBACK_VERSION"
}

# Main script
case "${1:-deploy}" in
    deploy)
        deploy
        ;;
    rollback)
        rollback
        ;;
    *)
        echo "Usage: $0 [deploy|rollback]"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy the Lambda function (default)"
        echo "  rollback - Rollback to the previous version"
        echo ""
        echo "Environment variables:"
        echo "  FUNCTION_NAME - Lambda function name (auto-detected if not set)"
        echo "  REGION        - AWS region (default: us-west-2)"
        exit 1
        ;;
esac
