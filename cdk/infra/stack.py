from aws_cdk import Stack, Duration
from aws_cdk import aws_sqs as sqs
from constructs import Construct

class MyCdkStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs):
        super().__init__(scope, construct_id, **kwargs)

        sqs.Queue(
            self,
            "MyQueue",
            visibility_timeout=Duration.seconds(30),
        )
