#!/usr/bin/env bash
set -euo pipefail
# Usage: ./deploy_lambda.sh <function_name> <zip_file> [region]

./mvnw package

# Parameters
LAMBDA_FUNCTION_NAME="${1:-tf-poc-compute}"
ZIP_FILE="${2:-}"
AWS_REGION="${3:-us-east-2}"

# Validate inputs
if [[ -z "$LAMBDA_FUNCTION_NAME" ]]; then
  echo "Usage: $0 <function_name> <zip_file> [region]"
  exit 1
fi

# Default to first .zip file in /target/ if ZIP_FILE not provided
if [[ -z "$ZIP_FILE" ]]; then
  ZIP_FILE=$(find ./target -maxdepth 1 -type f -name '*.zip' | head -n 1 || true)
  if [[ -z "$ZIP_FILE" ]]; then
    echo "Error: No .zip file found in ./target directory."
    exit 2
  fi
fi

echo "Deploying Lambda function: $LAMBDA_FUNCTION_NAME"
echo "ZIP file: $ZIP_FILE"
echo "Region: $AWS_REGION"

# Update the Lambda function code
aws lambda update-function-code \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --zip-file "fileb://$ZIP_FILE" \
  --region "$AWS_REGION"

echo "Deployment complete."


