# Saga Demo

This will be a demo of a saga.

## Elements

The data_lambda will be deployed to about 4 lambdas

- Write to database
- Unwrite to database (compensating transaction)
- Remote API call
- Issue Cancellation to Remote API

To keep things simple, no SQS.

But it will be wrapped in a Step Function.