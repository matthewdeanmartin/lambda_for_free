# Terraform

The modules are not 3rd party. So quality isn't that great. The goal was to learn.

## Java Spring Lambda Module

This is the HTTP API Gateway plus Spring-in-a-Lambda.

It doesn't deploy the Java code.

It does have the SQS and worker Lambda for an async workflow.

## Java Spring Lambda REST Gateway

The Terraform is much, much more verbose than for HTTP-style.

The ASG to SQS integration doesn't work.

## Poor Man's RDS
This is an ec2 machine with Postgres. It assumes no NAT gateway, security is via security groups.

## Static Website
This is just a basic S3 bucket.


## Deployment
Go to each applications directory and run the corresponding `./deploy.sh` script.


## TODO
- [ ] Template output so URL documentation can be copy pasted to REAMDME.md
- [ ] Unit tests
- [ ] PROD/DEV configuration
- [ ] Debug/no-debug. e.g. disable logging, which saves money.