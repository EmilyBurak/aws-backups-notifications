# BACKUP RESOURCES

# Backup vault for storing backups
resource "aws_backup_vault" "backup_vault" {
  name        = "backup-vault"
  kms_key_arn = aws_kms_key.backup_key.arn

  tags = {
    Name    = "backup-vault"
    Project = "aws-backups-test"
  }
}

# Backup plan for scheduling backups
resource "aws_backup_plan" "backup_plan" {
  name = "backup-plan"
  rule {
    rule_name         = "backup-rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 * * * ? *)"
    completion_window = 120
    start_window      = 60
    lifecycle {
      delete_after = 1
    }
  }
}

# Backup selection for selecting resources to backup
resource "aws_backup_selection" "backup_selection" {
  name         = "backup-selection"
  plan_id      = aws_backup_plan.backup_plan.id
  iam_role_arn = data.aws_iam_role.backup_default_role.arn
  resources    = [aws_instance.web.arn]
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Name"
    value = "backup-test-instance"
  }
}

data "aws_iam_role" "backup_default_role" {
  name = "AWSBackupDefaultServiceRole"
}

# Backup KMS Key
resource "aws_kms_key" "backup_key" {
  description = "KMS key for backup"
  tags = {
    Name    = "backup-test-kms-key"
    Project = "aws-backups-test"
  }
}

# BACKUP MONITORING AND NOTIFICATIONS

# Backup Vault Notifications
resource "aws_backup_vault_notifications" "backup_notification" {
  backup_vault_name = aws_backup_vault.backup_vault.name
  sns_topic_arn     = aws_sns_topic.backup_topic.arn
  backup_vault_events = [
    "BACKUP_JOB_STARTED",
    "BACKUP_JOB_FAILED",
    "BACKUP_JOB_EXPIRED",
  ]
}

# Backup SNS topic notifications are sent to
resource "aws_sns_topic" "backup_topic" {
  name = "backup-topic"
  tags = {
    Name    = "backup-topic"
    Project = "aws-backups-test"
  }
}

data "aws_iam_policy_document" "backup_sns_policy" {
  policy_id = "BackupSNSTopicPolicy"
  statement {
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
    resources = [aws_sns_topic.backup_topic.arn]

    sid = "AllowBackupServiceToPublish"
  }
}

resource "aws_sns_topic_policy" "backup_sns_policy" {
  arn    = aws_sns_topic.backup_topic.arn
  policy = data.aws_iam_policy_document.backup_sns_policy.json
}


# EC2 Instance for testing backups
resource "aws_instance" "web" {
  # US West 2 AMI for AWS Linux 2023, replace as you see fit
  ami           = "ami-0604d81f2fd264c7b"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.sn1.id

  tags = {
    Name    = "backup-test-instance"
    Project = "aws-backups-test"
  }
}

### NETWORKING Supportive Resources

# VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name    = "backup-test-vpc"
    Project = "aws-backups-test"
  }
}

# Private Subnet
resource "aws_subnet" "sn1" {
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "us-west-2a"

  tags = {
    Name    = "backup-test-subnet1"
    Project = "aws-backups-test"
  }
}
