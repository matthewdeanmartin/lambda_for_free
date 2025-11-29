from aws_cdk import (
    Stack,
    aws_s3 as s3,
    aws_iam as iam,
)
from constructs import Construct

class UiBucketStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, *, bucket_name: str, site_name: str, environment: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Create the S3 Bucket
        ui_bucket = s3.Bucket(
            self, "UiBucket",
            bucket_name=bucket_name,
            removal_policy=s3.RemovalPolicy.DESTROY,
            auto_delete_objects=True,
            website_index_document="index.html",
            website_error_document="index.html",
            block_public_access=s3.BlockPublicAccess(
                block_public_acls=False,
                block_public_policy=False,
                ignore_public_acls=False,
                restrict_public_buckets=False,
            ),
            lifecycle_rules=[
                s3.LifecycleRule(
                    enabled=True, # Optional, lifecycle exists to allow later lifecycle rules
                    abort_incomplete_multipart_upload_after=None, # No specific lifecycle
                )
            ]
        )

        # Add Tags
        ui_bucket.node.default_child.cfn_options.metadata = {
            "Name": site_name,
            "Environment": environment
        }

        # Bucket Policy: Allow Public Read
        ui_bucket.add_to_resource_policy(
            iam.PolicyStatement(
                sid="PublicReadGetObject",
                actions=["s3:GetObject"],
                resources=[f"arn:aws:s3:::{bucket_name}/*"],
                principals=[iam.ArnPrincipal("*")],
                effect=iam.Effect.ALLOW
            )
        )
