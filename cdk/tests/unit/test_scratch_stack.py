import aws_cdk as core
import aws_cdk.assertions as assertions

from infra.stack import MyCdkStack

def test_sqs_queue_created():
    app = core.App()
    stack = MyCdkStack(app, "x")
    template = assertions.Template.from_stack(stack)

    template.has_resource_properties("AWS::SQS::Queue", {
        "VisibilityTimeout": 30
    })
