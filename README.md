# lambda_for_free
Goal is to demo running web server code in lambdas for nearly free on AWS

## Demo site:
- [Angular UI](http://lambda-for-free-asdf-ui.s3-website.us-east-2.amazonaws.com/)
- [React UI](http://lambda-for-free-react-asdf-ui.s3-website.us-east-2.amazonaws.com/)
- [Swagger UI](http://lambda-for-free-asdf-ui.s3-website.us-east-2.amazonaws.com/swagger-ui.html)
- [Swagger Json](http://lambda-for-free-asdf-ui.s3-website.us-east-2.amazonaws.com/v3/api-docs)

## Three main approaches
- [Lambda Java Core](https://docs.aws.amazon.com/lambda/latest/dg/lambda-java.html) This is the simplest, but it is not a framework. Other than handling the serialization to bind to the function, all other common application problems normally solved by a framework will have to be reinvented from scratch, which could take years and will still not be as good as Spring.
- [Spring Cloud Function](https://docs.spring.io/spring-cloud-function/docs/current/reference/html/spring-cloud-function.html) This lets you run Spring code in a function in any cloud (AWS, Azure, GCP). It does not have the full feature set of Spring Web. It requires code modification for replatforming. It has somewhat better support for responding to message queue events instead of web events.
- [Serverless Java Container](https://github.com/aws/serverless-java-container/wiki/Quick-start---Spring-Boot3) This lets you run the same web code locally as in the lambda runtime. The API Gateway and Lambda become a transparent replacement for Tomcat. This code is ideal for replatformating and leaving open the option of switch to hosting in ECS should the organization's mandated authentication, logging prove to be incompatible with API Gateway. The other common reason for abandoning Lambda is that at high load, it become prohibitively expensive. At low load, lambdas are almost free.

## Roadmap for demo code
The demo app will be an API that solves common tech interview problems, such as fizzbuzz and sliding window.


## Challenges
- Used archetype, see [generate.sh](generate.sh) for syntax. Important to update versioon before running.
- Had to comment out the "exclude tomcat", or you can't run the website locally.
- Had to increase log level to INFO in applications.properties, or you can't tell if Tomcat is running or on which port.


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