#!/bin/bash
set -euo pipefail

export AWS_PROFILE=moto
terraform apply current.plan