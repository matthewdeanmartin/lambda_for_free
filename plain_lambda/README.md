# Plain Lambda Worker

This is a simple worker that consumes an SQS message or a direct message and calculates a logarithm.

If it is an async request, it stores the result in a DynamoDB table.

There are many signatures that a lambda can implement, this one uses 

`public String handleRequest(Map<String, Object> event, Context context)`

## Challenges
- The SQS message body came through as a peculiar json format, not the one I sent.
- Some sort of retry logic was going on filling the logs with extra calls
- This has no elements of Spring Web at all. No Spring ORMs, nothing.