#!/bin/bash
set -euo pipefail

# export AWS_PROFILE=moto
terraform fmt
terraform validate
# Can't run at same time because they both use the .terraform folder.
#tofu validate
#tofu plan -out tofu.plan
terraform plan -out current.plan -var-file="variables_dev.tfvars"