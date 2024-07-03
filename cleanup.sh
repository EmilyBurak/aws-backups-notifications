#!/bin/bash

set -e

if [ -z "$1" ]; then
    read -p "Enter the stage for the cleanup: " stage
    else stage=$1
fi

if [ -z "$2" ]; then
    read -p "Enter the region for the cleanup: " region
    else region=$2
fi

printf "Beginning cleanup...\n"
printf "Grabbing values to delete lambda function and backup job...\n"

# Run the terraform
terraform init -input=false
json=$(terraform output -json)

# Get output of topic arn to use in removing the serverless function and stopping backup jobs
backup_topic_arn=$(echo $json | jq -r .backup_topic_arn.value)

printf "\n-----------------\n"
printf "Values grabbed!\n"

printf "\n-----------------\n"
printf "Removing the serverless function...\n"
cd python
npm install
node ./node_modules/.bin/serverless remove --stage $stage --region $region --param "backup_topic_arn=${backup_topic_arn}"
cd .. 

printf "\n-----------------\n"
printf "Stopping all active backup jobs...\n"
aws backup list-backup-jobs \
    --by-state RUNNING  \
    --query 'BackupJobs[].BackupJobId' \
    --output text | xargs -t -n1 aws backup stop-backup-job --backup-job-id | echo "All RUNNING state backup jobs stopped."

aws backup list-backup-jobs \
    --by-state CREATED  \
    --query 'BackupJobs[].BackupJobId' \
    --output text | xargs -t -n1 aws backup stop-backup-job --backup-job-id | echo "All CREATED state backup jobs stopped."

# needed cleanup of recovery points before deleting the backup vault
# https://gist.github.com/scgoeswild/3f17292bf95d27420b513bb3d8e3d16c

# Get the backup vault name
VAULT_NAME=$(echo $json | jq -r .backup_vault_name.value)

printf "\n-----------------\n"
printf "Cleaning up ${VAULT_NAME} ...\n"

for ARN in $(aws backup list-recovery-points-by-backup-vault --backup-vault-name "${VAULT_NAME}" --query 'RecoveryPoints[].RecoveryPointArn' --output text); do 
  echo "deleting ${ARN} ..."
  aws backup delete-recovery-point --backup-vault-name "${VAULT_NAME}" --recovery-point-arn "${ARN}"
done

# Run the terraform destroy
printf "\n-----------------\n"
printf "Destroying the terraform resources...\n"
terraform destroy -auto-approve

echo "Cleanup complete!"