variable "project_name" {
  description = "Short name used to identify the state resources."
  type        = string
  default     = "webservice"
}

variable "aws_region" {
  description = "AWS region in which to store Terraform state."
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "AWS region receiving a replica of Terraform state."
  type        = string
  default     = "us-west-2"

  validation {
    condition     = var.dr_region != var.aws_region
    error_message = "dr_region must differ from aws_region."
  }
}

variable "tags" {
  description = "Additional tags applied to state resources."
  type        = map(string)
  default     = {}
}