variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "リソース名のプレフィックスとして使用するプロジェクト名"
  type        = string
  default     = "chat-app"
}

variable "log_retention_days" {
  description = "CloudWatch Logsの保持日数"
  type        = number
  default     = 7
}
