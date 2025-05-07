# test_snapstart_checker.py

import boto3
from moto import mock_lambda
import pytest
from snapstart_checker import check_lambda_snapstart

@mock_lambda
def test_check_lambda_snapstart():
    lambda_client = boto3.client("lambda", region_name="us-east-1")

    # Create a Lambda function
    fn_name = "test-function"
    role_arn = "arn:aws:iam::123456789012:role/service-role/test-role"
    lambda_client.create_function(
        FunctionName=fn_name,
        Runtime="java11",
        Role=role_arn,
        Handler="index.handler",
        Code={"ZipFile": b"test"},
        Description="Test function",
        Timeout=3,
        MemorySize=128,
        Publish=True,
        Architectures=["arm64"]
    )

    # Update function configuration to enable SnapStart
    lambda_client.update_function_configuration(
        FunctionName=fn_name,
        SnapStart={"ApplyOn": "PublishedVersions"}
    )

    # Publish a new version
    lambda_client.publish_version(FunctionName=fn_name)

    # Run the check
    issues = check_lambda_snapstart(lambda_client)

    # Assert no issues found
    assert issues == []
