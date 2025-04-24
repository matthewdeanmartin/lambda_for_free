#!/bin/bash

# Define the source and destination
SOURCE_FILE="lambda_shim/main.py"
ZIP_FILE="main.zip"

# Create a zip file using Python
python3 - <<EOF
import shutil
shutil.make_archive('main', 'zip', '../lambda_shim', 'main.py')
EOF

echo "Zipped $SOURCE_FILE into $ZIP_FILE"