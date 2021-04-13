#!/usr/bin/env bash

set -euo pipefail

source search-api-git/ltr/concourse/lib.sh

assume_role

EC2_NAME="govuk-${GOVUK_ENVIRONMENT}-search-ltr-generation"
AWS_REGION="eu-west-1"

echo "Scaling down ASG..."
aws autoscaling set-desired-capacity \
    --region "$AWS_REGION" \
    --auto-scaling-group-name "$EC2_NAME" \
    --desired-capacity 0
