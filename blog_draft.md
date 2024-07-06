AWS Backup Notifications to Slack
Introduction
My use case for this project was wiring up AWS Backup notifications to Slack, which I focused on implementing using EC2 backups for ease of use in learning the service and its Terraform resources, you can check out the repo here. Turns out there's a convenient Terraform resource for AWS Backup vault notifications! From there, I decided on using a Lambda in Python to process the notifications, as that's a nice and simple way to do it.
Figuring out wiring up the lambda to Slack and the particularly special new thing to me of serverless framework deployment was a chunk of the work, including figuring out working with passed-in params from Terraform output and other wrinkles. Finally, I scripted out deploying the infrastructure, running a test and cleaning it all up.
The project uses Terraform to set up AWS infrastructure, the Serverless Framework to manage the Lambda function, and bash scripts to automate deployment and cleanup. The Lambda processes SNS notifications from AWS Backup and sends them to Slack.
Key Technologies Used
Terraform
AWS(Lambda, Backup, SNS primarily)
Serverless Framework
Bash
Slack

Prerequisites

1. AWS CLI
   Install the AWS CLI and configure it with AWS admin credentials.
   AWS CLI Installation Guide

2. Terraform
   Install Terraform to manage the infrastructure.
   Terraform Installation Guide

3. Node.js and npm
   Install Node.js and npm to manage JavaScript dependencies.
   Node.js Installation Guide

4. Serverless Framework
   Install the Serverless Framework globally using npm.
   npm install -g serverless
   Serverless Framework Documentation

5. Slack Webhook URL
   Create a Slack App and obtain a webhook URL.
   Replace the SLACK_ENDPOINT in serverless.yaml with your Slack webhook URL.
   Slack Webhook Setup Guide

Main Infrastructure and Components

1. Terraform Infrastructure
   Files: main.tf, outputs.tf
   Purpose: Defines the AWS infrastructure required for the project.

Backup Vault: Stores backups.
Backup Plan: Schedules backups.
Backup Selection: Selects resources to backup(the test EC2 instance here).
SNS Topic: Receives notifications from AWS Backup(for "BACKUP_JOB_STARTED" "BACKUP_JOB_FAILED", "BACKUP_JOB_EXPIRED" and "BACKUP_JOB_COMPLETED" events).
EC2 Instance: Used for testing backups.
IAM Roles and Policies: Provide necessary permissions.
Notes: I didn't utilize modules here, that's best practice and for a production project I'd break the (inevitably more complex) infrastructure down into more organized and reusable modules. As well, there's no remote backend in here. If you're able to set this up, you're able to move it to an S3 backend. Here, have a blog about that.

2. Serverless Framework
   Files: /python/serverless.yaml, /python/handler.py
   Purpose: Deploys and manages the AWS Lambda function.

handler.py: Triggered by SNS events, parses the event, and sends a notification to Slack.
serverless.yaml: Defines the Lambda function, its environment variables, and the SNS event source.
Notes: There's are arguments to be made for managing the Lambda in Terraform more or less vs. Serverless, YMMV on what works for you, managing Lambdas in Terraform can be tricky, for an example see my AWS to Datadog Lambda via. Terraform repo.

3. Bash Scripts
   Files: entrypoint.sh, cleanup.sh
   Purpose: Automates the deployment and teardown of the infrastructure.

entrypoint.sh: Sets up the infrastructure, deploys the Lambda function, and starts a backup job.
cleanup.sh: Cleans up the resources and stops any running backup jobs.
Notes: In production, I'd use a more proper CI/CD solution using something like GH Actions.

4. Slack Integration
   Files: /python/handler.py, /python/serverless.yaml
   Purpose: Sends notifications to a Slack channel.
   Slack Webhook URL: Configured in serverless.yaml and used in handler.py to send messages.
   Notes: I used urllib3 here for HTTP requests, you can use requests or your favorite library for that, or subprocess call curl or whatever you want, it's a POST request silly.

Interaction Flow

1. Deployment:
   entrypoint.sh initializes and applies the Terraform configuration (main.tf), setting up the necessary AWS resources.
   Outputs from Terraform are used to configure the Serverless Framework deployment.
   The Serverless Framework deploys the Lambda function (handler.py) which is configured to trigger on SNS events.

2. Backup Job:
   An on-demand backup job is started using the AWS CLI within entrypoint.sh.
   AWS Backup sends notifications to the SNS topic upon job state changes (e.g., started, completed, failed).

3. Notification Handling:
   The SNS topic triggers the Lambda function (handler.py).
   The Lambda function parses the SNS message and sends a formatted notification to the configured Slack channel.

4. Teardown:
   cleanup.sh stops any running backup jobs, deletes recovery points, and destroys the Terraform-managed resources.

How To Use

1. Run entrypoint.sh
   This script sets up the necessary infrastructure and runs an on-demand AWS Backup job.
   It accepts two arguments: a stage (default is dev) and a region (default is us-east-1).
   Example: ./entrypoint.sh dev us-west-2

2. Run cleanup.sh
   This script cleans up the resources and any running or just created but not yet run jobs.
   It accepts two arguments: a stage and a region.
   Example: /cleanup.sh dev us-west-2

Things I Learned
Got some familiarity with Backup - its start/completion windows, how it handles deleting vaults, the Default vault popped up for a moment there, and more. The docs aren't the best, including a table they have listing the supported events for Notifications which is incorrect, not listing BACKUP_JOB_FAILED very critically.
Took a couple of different approaches including looking at EventBridge before deciding on an SNS topic to a Lambda for simplicity. Originally had more code for various things like more logging but cut it down in the end, going from 20-something Terraform resources to 10 for example.
Worked on some bash, learned or recalled some good AWS CLI syntax like aws ec2 wait instance-status-ok is helpful to remember.
Backup requires little networking configuration, not requiring specific network connectivity from an EC2 resource for example, and even supporting cross-region backups - at first I was presuming I'd need to have some particular ingress or egress set up.
Fun reminder while formatting the final messages to send to Slack - Slack uses the markup language mrkdwn instead of markdown as detailed here, which does trip me up because everything uses markdown these days, right?

TO DO
Work with other services than just EC2 in conjunction with Backup, mostly RDS, which would've been more cumbersome to test and learn the service.

Resources
https://aws.amazon.com/blogs/storage/configuring-notifications-to-monitor-aws-backup-jobs/ - Overview of using AWS Backup Vault Notifications with SNS.
https://aws.amazon.com/blogs/storage/amazon-cloudwatch-events-and-metrics-for-aws-backup/ - Another way of monitoring and alerting on AWS Backup, using EventBridge.
https://aws.amazon.com/blogs/storage/automate-data-recovery-validation-with-aws-backup/ - An interesting solution for a automated data recovery validation pipeline to test backups, good example of using monitoring and Lambda with Backup.
https://docs.aws.amazon.com/aws-backup/latest/devguide/api-reference.html - Backup API docs.
https://gist.github.com/scgoeswild/3f17292bf95d27420b513bb3d8e3d16c - For cleaning up the Vault.
https://docs.aws.amazon.com/cli/latest/reference/ec2/wait/instance-status-ok.html - I hadn't used this helpful API call before, used to wait for EC2 instances to fully start up.
https://www.youtube.com/watch?v=m9dhrq9iRHA and https://www.youtube.com/watch?v=j7xZ2VkLYIY - jq tutorials, it's helpful for everything from parsing Terraform output to working with AWS CLI data, JSON is everywhere

Conclusion
