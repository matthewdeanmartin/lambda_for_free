# Spring Web and AWS API Gateway HTTP-sytle

This demos

- Domain is
    - Interview coding challenge code
    - Logarithms calculator (async)
- Spring web running in lambda
- Can connect by Lambda URL or API Gateway
- Can make sync calls
- Can make async call via Message Controller
    - Create SQS message + dynamodb
    - SQS message consumed by plain_lambda (see repo), which puts result into DynamoDB
    - Poll for final message

## Benefits of *this* kind of Async

- Process can run more than 30 seconds. With plain API Gateway, it times out after 30 seconds, even if lambda isn't
  done.
- Unclear what network queueing is available for API Gateway out of the box
    - Does it drop requests?
    - Does it cause all other requests to wait?
    - Are requests serialized? (1 request must finish before next)
- SQS queues can be processed in batch, saving Lambda call costs at cost of guaranteed minimum latency.

## Benefits of *other* kinds of Async

For example, the `async` keyword in python and C#, or the whole model of Javascript is to make sure a thread that is
doing IO, e.g. waiting for a database or a 3rd party web API call to return, doesn't consume resources. But for
lambdas, the lambda is consuming resources unless you can, effectively, terminate the whole process. Inside a lambda, an
async call isn't consuming CPU, but the lambda is still running so it still costs money to wait.

You can make requests in parallel with the `async` keyword and save time.

Almost no databases allow for fire and forget invocation of SQL. If a connection ends (because the lambda ended), then
the transaction is rolled back or won't necessarily run to completion.

The closest would be a crazy hack, like creating a SQL cron task that executes immediately.

## Notes

- Used archetype, see [generate.sh](generate.sh) for syntax. Important to update versioon before running.
- Had to comment out the "exclude tomcat", or you can't run the website locally.
- Had to increase log level to INFO in applications.properties, or you can't tell if Tomcat is running or on which port.


