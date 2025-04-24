#!/bin/bash
set -euo pipefail

export AWS_PROFILE=moto
terraform destroy -var-file="variables.tfvars"