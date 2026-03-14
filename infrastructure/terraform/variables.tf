variable "environment" {
  type        = string
  description = "Deployment environment: dev | test | prod"
  default     = "dev"
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod"
  }
}

variable "location" {
  type        = string
  description = "Azure region for all resources"
  default     = "westeurope"
}
