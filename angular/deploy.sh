#!/usr/bin/env bash
set -euo pipefail

# Configuration
BUCKET_NAME="lambda-for-free-angular-asd-ui"
PROJECT_NAME="angular"
DIST_DIR="dist/$PROJECT_NAME/browser"
BUILD_CONFIG="production"
REGION="us-east-2"
INDEX_FILE="index.html"
ERROR_FILE="index.html"  # Angular handles routing

echo "🔨 Building Angular app..."
ng build --configuration "$BUILD_CONFIG"

echo "📁 Built app located at: $DIST_DIR"

if [[ ! -d "$DIST_DIR" ]]; then
  echo "❌ Error: Built directory '$DIST_DIR' not found!"
  exit 1
fi

echo "🧹 Cleaning up existing S3 content..."
aws s3 rm "s3://$BUCKET_NAME" --recursive --region "$REGION"

echo "⬆️ Uploading new content to S3 root..."
aws s3 cp "$DIST_DIR" "s3://$BUCKET_NAME" --recursive --region "$REGION"

echo "🌐 Setting website configuration..."
aws s3 website "s3://$BUCKET_NAME" --index-document "$INDEX_FILE" --error-document "$ERROR_FILE"

echo "✅ Deployment complete!"
echo "🌍 Site URL: http://$BUCKET_NAME.s3-website.$REGION.amazonaws.com/"
