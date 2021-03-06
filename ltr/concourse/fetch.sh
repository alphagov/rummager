#!/usr/bin/env bash

set -euo pipefail

source search-api-git/ltr/concourse/lib.sh

assume_role

EC2_NAME="govuk-${GOVUK_ENVIRONMENT}-search-ltr-generation"
S3_BUCKET="govuk-${GOVUK_ENVIRONMENT}-search-relevancy"
GIT_BRANCH="deployed-to-${GOVUK_ENVIRONMENT}"
AWS_REGION="eu-west-1"

echo "Scaling up ASG..."
aws autoscaling set-desired-capacity \
    --region "$AWS_REGION" \
    --auto-scaling-group-name "$EC2_NAME" \
    --desired-capacity 1

instance_id=""
while [[ "$instance_id" == "" ]]; do
  echo "    still waiting for instance ID..."
  sleep 30
  instance_id=$(aws ec2 describe-instances --region "$AWS_REGION" --query "Reservations[*].Instances[*].InstanceId" --filters Name=instance-state-name,Values=running,pending  Name=tag:Name,Values="$EC2_NAME" --output=text)
done

echo "Waiting on instance ${instance_id}..."
aws ec2 wait instance-status-ok \
    --region "$AWS_REGION" \
    --instance-ids "${instance_id}"

echo "$SSH_PRIVATE_KEY" > /tmp/concourse_ssh_key
chmod 400 /tmp/concourse_ssh_key

instance_ip=$(aws ec2 describe-instances --region "$AWS_REGION" --query "Reservations[*].Instances[*].PublicIpAddress" --filter Name=tag:Name,Values="$EC2_NAME" --output=text)

echo "Connecting to instance..."
NOW="$(date +%s)"
ssh -i /tmp/concourse_ssh_key -o StrictHostKeyChecking=no "ubuntu@${instance_ip}" << EOF
  set -euo pipefail

  sudo apt-get update
  sudo apt-get install -y awscli git

  # docker setup from https://docs.docker.com/install/linux/docker-ce/ubuntu/
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get -y install docker-ce docker-ce-cli containerd.io

  cd /tmp
  git clone --depth 1 --branch $GIT_BRANCH https://github.com/alphagov/search-api.git
  cd search-api
  docker="sudo docker run -v \$(pwd):/work -v bundle:/usr/local/bundle -e ENABLE_LTR=true -e BIGQUERY_CREDENTIALS=$BIGQUERY_CREDENTIALS -e ELASTICSEARCH_URI=$ELASTICSEARCH_URI -w /work --rm ruby:\$(cat .ruby-version)"
  \$docker bundle

  mkdir tmp
  echo "pulling data from bigquery"
  \$docker bundle exec rake 'learn_to_rank:fetch_bigquery_export[bigquery]'
  aws s3 cp tmp/bigquery.csv s3://$S3_BUCKET/data/$NOW/bigquery.csv

  echo "generating relevance judgements"
  \$docker bundle exec rake 'learn_to_rank:generate_relevancy_judgements[tmp/bigquery.csv,judgements]'
  aws s3 cp tmp/judgements.csv s3://$S3_BUCKET/data/$NOW/judgements.csv

  echo "Generating NDCG test data from top queries"
  # Magic number based on top 1000 search terms from past 6 months
  \$docker bundle exec rake 'learn_to_rank:fetch_bigquery_export[bigquery_small,2000]'
  \$docker bundle exec rake 'learn_to_rank:generate_relevancy_judgements[tmp/bigquery_small.csv,autogenerated_judgements]'
  aws s3 cp tmp/autogenerated_judgements.csv s3://$S3_BUCKET/autogenerated_judgements.csv

  echo "generating training dataset"
  \$docker bundle exec rake 'learn_to_rank:generate_training_dataset[tmp/judgements.csv,svm]'
  aws s3 cp svm/train.txt    s3://$S3_BUCKET/data/$NOW/train.txt
  aws s3 cp svm/test.txt     s3://$S3_BUCKET/data/$NOW/test.txt
  aws s3 cp svm/validate.txt s3://$S3_BUCKET/data/$NOW/validate.txt
EOF

# the previous assumption may have timed out, so assume again before
# scaling down the ASG
assume_role

echo "Scaling down ASG..."
aws autoscaling set-desired-capacity \
    --region "$AWS_REGION" \
    --auto-scaling-group-name "$EC2_NAME" \
    --desired-capacity 0

echo "$NOW" > "out/${GOVUK_ENVIRONMENT}-${OUTPUT_FILE_NAME}-$(date +%s).txt"
