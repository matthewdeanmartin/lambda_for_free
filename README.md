# lambda_for_free
Goal is to demo running web server code in lambdas for nearly free on AWS

## Three main approaches
- [Lambda Java Core](https://docs.aws.amazon.com/lambda/latest/dg/lambda-java.html) This is the simplest, but it is not a framework. Other than handling the serialization to bind to the function, all other common application problems normally solved by a framework will have to be reinvented from scratch, which could take years and will still not be as good as Spring.
- [Spring Cloud Function](https://docs.spring.io/spring-cloud-function/docs/current/reference/html/spring-cloud-function.html) This lets you run Spring code in a function in any cloud (AWS, Azure, GCP). It does not have the full feature set of Spring Web. It requires code modification for replatforming. It has somewhat better support for responding to message queue events instead of web events.
- [Serverless Java Container](https://github.com/aws/serverless-java-container/wiki/Quick-start---Spring-Boot3) This lets you run the same web code locally as in the lambda runtime. The API Gateway and Lambda become a transparent replacement for Tomcat. This code is ideal for replatformating and leaving open the option of switch to hosting in ECS should the organization's mandated authentication, logging prove to be incompatible with API Gateway. The other common reason for abandoning Lambda is that at high load, it become prohibitively expensive. At low load, lambdas are almost free.

## Roadmap for demo code
The demo app will be an API that solves common tech interview problems, such as fizzbuzz and sliding window.

- Evaulate the 3+ different maven archetyes, project starter kits, spring starter templates
- Create terraform to create minimal setup
- Create build pipeline (with github and gitlab)
- Create sample endpoints in each framework
- Create sample test code (curl, postman, unit tests)
