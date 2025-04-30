# lambda_for_free
Two goals:
- Implement serverless patterns
- Figure out how to 

The goal is to demo multiple design and architectural patterns that use AWS lambdas and API Gateway.


## Patterns Done so far:
- Web server with serverside rendering in lambda (API Gateway HTTP-style +  Spring Boot in Lambda)
  - (See other repo)
- Spring Web API + API Gateway REST-style. In theory has more features and tasks that can be off loaded to API Gateway
- Spring Web API + API Gateway HTTP-style. Very little offloaded to Gateway, but much simpler to setup and manage. 
- TODO: Async patterns
  - API Gateway to Lambda that only enqueues SQS messages, polls results. SQS messages read by Cloud Function.
- TODO:
  - Lambda Function URL. Can we cut out the API Gateway altogether?

Why should API gateway talk direct to spring in java-serverless-container? Because it feels like web development and is web development.

If your client isn't a web browser, then sure, consider making sdk/boto calls directly to your lambdas.

Why should a lambda calling a lambda not using java-serverless-container? Because, unless there is HTTP call, there isn't any HTTP going on, so it is extra.

## Didn't work
- API Gateway to SQS to java-serverless-container. Requires more json transformation logic than is easy to implement with velocity templates.


## Synchronous Spring with HTTP Api Gateway:
- [Swagger UI](https://hlg0m0h7e6.execute-api.us-east-2.amazonaws.com/swagger-ui.html)
- [Swagger Json](https://hlg0m0h7e6.execute-api.us-east-2.amazonaws.com/v3/api-docs)

Corresponding UIs:
- [Angular UI](http://lambda-for-free-asdf-ui.s3-website.us-east-2.amazonaws.com/)
- [React UI](http://lambda-for-free-react-asdf-ui.s3-website.us-east-2.amazonaws.com/)

## Three main approaches
- [Lambda Java Core](https://docs.aws.amazon.com/lambda/latest/dg/lambda-java.html) This is the simplest, but it is not a framework. Other than handling the serialization to bind to the function, all other common application problems normally solved by a framework will have to be reinvented from scratch, which could take years and will still not be as good as Spring.
- [Spring Cloud Function](https://docs.spring.io/spring-cloud-function/docs/current/reference/html/spring-cloud-function.html) This lets you run Spring code in a function in any cloud (AWS, Azure, GCP). It does not have the full feature set of Spring Web. It requires code modification for replatforming. It has somewhat better support for responding to message queue events instead of web events.
- [Serverless Java Container](https://github.com/aws/serverless-java-container/wiki/Quick-start---Spring-Boot3) This lets you run the same web code locally as in the lambda runtime. The API Gateway and Lambda become a transparent replacement for Tomcat. This code is ideal for replatformating and leaving open the option of switch to hosting in ECS should the organization's mandated authentication, logging prove to be incompatible with API Gateway. The other common reason for abandoning Lambda is that at high load, it become prohibitively expensive. At low load, lambdas are almost free.


## AWS Docs
- [Async with SQS](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/integrate-amazon-api-gateway-with-amazon-sqs-to-handle-asynchronous-rest-apis.html)
- [Async with SQS and REST AGW](https://github.com/aws-samples/asynchronous-event-processing-api-gateway-sqs-cdk)

## Notes for Thurs 24
- Angular UI
  - Angular code now calls the API Gateway
  - "proxy config" allows local website to call local API server.
  - Angular code deployed to s3 website.
- API Gateway
  - CORS is handled by API Gateway (Although I'm sure Spring could handle the CORS requests too)
  - Terraform in place for API Gateway to logs errors. The web console by default doesn't provide error logging!
  - Java Serverless Container supports only v1 of the Api Gateway payload.
- Snapstart
  - Snapshot is mandatory because of Java's slow start problems.
  - Other initialization tricks exist
  - There are snapstart events that you may need to register to rebuild/close things like connection strings that were loaded on start

## API Gateway vs Tomcat/ALB
Request pipeline features
- API Gateway can handle CORS. So can Spring.
- API Gateway can handle rate limiting on a per acct/per route basis.
- API Gateway can handle Authentication/Authorization (via lambda authorizer & JWT/OAUTH)

Routing
- API Gateway can route based on URL paths.
  - Or you can just forward everything to one lambda and let Spring route to a controller.
  - Or you can route to a mixture of microservices, lambdas, or AWS APIs
- API Gateway can handle stages routing (stages) and version routing (routes)

Metadata
- API Gateway can import/export OpenAPI

Domains and Certs
- API Gateway can do the same custom domain, HTTPS cert features of an ELB/ALB

Request transformation
- API Gateway can do minor tweaking of headers (parameter mapping)

30 second timeout!
No security groups, only WAF



## Architectual patterns to try out
- API Gateway + SQS + Lambda with polling
- API Gateway + SQS + Lambda with callback
- API Gateway + SQS + Lambda with fire and forget/batch processing
- API Gateway + (SQS) _ Lambda  - Lambda