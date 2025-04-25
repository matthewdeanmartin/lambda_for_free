# Async version
This is a lambda + AWS API Gateway REST style. 

## AWS API Gateway REST Style
Cons
- Much more complicated, a lot more terraform code
- Deployment cycles can take the website *offline* for 20 seconds to a few minutes.

Pros
- You can integrate with SQS and get full control over the payload format using Velocity. Haven't figured out how to with HTTP-style.

## AWS API Gateway REST Style vs Tomcat/ALB
Many of the same pros and cons as HTTP style.

## Thoughts on attempting to use SQS as a request queue
- Can't seem to do this with HTTP API Gateway, can't transform the payload.
- REST API Gateway rough edges
  - If you transform the payload with velocity wrong, you can get IAM SQS errors (Permission denied?!)
  - ... which goes away with a simpler transform
  - Constantly need to "deploy a stage", terraform doesn't necessarily pick up on when a stage needs to be redeployed.
  - API gateway is unresponsive/slow while stage deployment is going on
- Request size is limited can't be larger that SQS maximum message size
- No way to send back a response, must poll
- Too hard to use velocity to create a compliant request object and put in the SQS message.