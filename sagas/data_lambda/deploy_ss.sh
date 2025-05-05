#!/usr/bin/env bash

# Usage: ./deploy_lambda.sh <function_name> [alias] [zip_file] [region]

set -euo pipefail

# Inputs
LAMBDA_FUNCTION_NAME="${1:-tf-poc-async-worker}"
ALIAS_NAME="${2:-}"
ZIP_FILE="${3:-target/plain_lambda.jar}"
AWS_REGION="${4:-us-east-2}"

# Validate function name
if [[ -z "$LAMBDA_FUNCTION_NAME" ]]; then
  echo "Usage: $0 <function_name> [alias] [zip_file] [region]"
  exit 1
fi

## Default zip file from /target
#if [[ -z "$ZIP_FILE" ]]; then
#  ZIP_FILE=$(find ./target -maxdepth 1 -type f -name '*.zip' | head -n 1 || true)
#  if [[ -z "$ZIP_FILE" ]]; then
#    echo "Error: No .zip file found in ./target directory."
#    exit 2
#  fi
#fi

if [[ ! -f "$ZIP_FILE" ]]; then
  echo "Error: ZIP file '$ZIP_FILE' not found."
  exit 3
fi

echo "Deploying Lambda function: $LAMBDA_FUNCTION_NAME"
echo "ZIP file: $ZIP_FILE"
echo "Region: $AWS_REGION"

# Step 1: Update function code
aws lambda update-function-code \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --zip-file "fileb://$ZIP_FILE" \
  --region "$AWS_REGION" > /dev/null

echo "Code updated successfully."

echo "Waiting for configuration update to complete..."
aws lambda wait function-updated \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --region "$AWS_REGION"

# Step 2: Publish a new version
VERSION=$(aws lambda publish-version \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --query 'Version' \
  --output text)

echo "Published version: $VERSION"

# Step 3: Enable SnapStart for the function (if not already enabled)
aws lambda update-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --snap-start ApplyOn=PublishedVersions > /dev/null

echo "SnapStart enabled for published versions."

# Step 4: Update alias to point to new version (if alias provided)
if [[ -n "$ALIAS_NAME" ]]; then
  echo "Updating alias '$ALIAS_NAME' to version $VERSION"

  # Try to update the alias or create it if it doesn't exist
  if aws lambda get-alias --function-name "$LAMBDA_FUNCTION_NAME" --name "$ALIAS_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    aws lambda update-alias \
      --function-name "$LAMBDA_FUNCTION_NAME" \
      --name "$ALIAS_NAME" \
      --function-version "$VERSION" \
      --region "$AWS_REGION"
  else
    aws lambda create-alias \
      --function-name "$LAMBDA_FUNCTION_NAME" \
      --name "$ALIAS_NAME" \
      --function-version "$VERSION" \
      --region "$AWS_REGION"
  fi

  echo "Alias '$ALIAS_NAME' now points to version $VERSION."
fi

echo "✅ Deployment complete with SnapStart and versioning."
