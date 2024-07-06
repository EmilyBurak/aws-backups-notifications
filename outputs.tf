output "ec2_id" {
  value = aws_instance.backup_test_instance.id
}

output "backup_vault_name" {
  value = aws_backup_vault.backup_vault.name
}

output "ec2_instance_arn" {
  value = aws_instance.backup_test_instance.arn
}

output "backup_default_role_arn" {
  value = data.aws_iam_role.backup_default_role.arn
}

output "backup_topic_arn" {
  value = aws_sns_topic.backup_topic.arn
}
