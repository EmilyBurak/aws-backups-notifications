#!/bin/bash

set -e

echo "Beginning the backup test..."

if [ -z "$1" ]; then
    read -p "Enter the stage for the deploy: " stage
    else stage=$1
fi

if [ -z "$2" ]; then
    read -p "Enter the region for the deploy: " region
    else region=$2
fi

# Run the terraform
terraform init
# saving to a tfplan file as well for debugging purposes
terraform plan -compact-warnings -input=false -out=tfplan

# Apply the terraform
terraform apply -auto-approve
json=$(terraform output -json)

# saving the json output to a file for debugging purposes as well
echo $json > output.json

# Get outputs to use in the backup job and serverless function
backup_vault_name=$(echo $json | jq -r .backup_vault_name.value)
resource_arn=$(echo $json | jq -r .ec2_instance_arn.value)
resource_id=$(echo $json | jq -r .ec2_id.value)
iam_role_arn=$(echo $json | jq -r .backup_default_role_arn.value)
backup_topic_arn=$(echo $json | jq -r .backup_topic_arn.value)

printf "\n-----------------\n"
printf "SETTING VARIABLES\n-----------------\n"
printf "The backup vault name is $backup_vault_name\n"
printf "The resource arn is $resource_arn\n"
printf "The iam role arn is $iam_role_arn\n"
printf "The backup topic arn is $backup_topic_arn\n"
printf "\n-----------------\n"
printf "VARIABLES SET\n-----------------\n"

printf "Waiting for the ec2 instance to be ready..."
aws ec2 wait instance-status-ok \
    --instance-ids $resource_id

printf "\n-----------------\n"
printf "EC2 instance is ready!\n"
printf "\n-----------------\n"

printf "Removing the serverless function to ensure topic association..."
printf "\n-----------------\n"
cd python
npm install

# Remove this if you are more okay than me with the serverless function potentially losing track of the SNS topic association
node ./node_modules/.bin/serverless remove --stage $stage --region $region --param "backup_topic_arn=${backup_topic_arn}"

printf "Deploying the serverless function..."

# Remove this serverless print if you need less words in your logs
node ./node_modules/.bin/serverless print --stage $stage --region $region --param "backup_topic_arn=${backup_topic_arn}" 
node ./node_modules/.bin/serverless deploy --stage $stage --region $region --param "backup_topic_arn=${backup_topic_arn}" --verbose --conceal

printf "Running the test backup job..."

# Run the backup job
aws backup start-backup-job \
    --backup-vault-name $backup_vault_name \
    --resource-arn $resource_arn \
    --iam-role-arn $iam_role_arn

printf "BACKUP JOB STARTED, Look for the backup job in Slack logs!\n-----------------\n"