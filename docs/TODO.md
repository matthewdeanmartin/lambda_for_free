## TODO
- Work on SQS & other async patterns.
    - API Gateway sends SQS message, Lambda handles it stores result, client polls another end point for result. CAN'T! Velocity templating problems.
    - API Gateway call lambda, lambda creates SQS message, client polls. DONE!!

- Work on Saga patterns
    - API Gateway calls step function, step function triggers SQS, Lambda and calls a compensating/rollback if fails.

## Roadmap
- Evaluate the 3+ different starter projects:
    - maven archetype (have to re-enable tomcat to run locally) - DONE!
    - Intellij project starter (No maven by default)
    - spring starter templates (needs many assets from the java serverless container example: assembly, pom profiles, etc) - DONE!
- Create terraform to create minimal setup- DONE!
- Create build pipeline (with github and gitlab)
- Create sample endpoints in each framework
- Create sample test code (curl, postman, unit tests)

## Async patterns
- AGW -> SQS -> Lambda. Allows more concurrent requests w/o dropping requests when maximum number of live lambdas is hit. 
Responses have to be save somewhere in a db and returned via polling
- Websocket or Step function/Callbacks. Complicated looking
- 