locals {
  bucket_name = "${var.project_name}-${data.aws_caller_identity.current.account_id}-tfstate"
}