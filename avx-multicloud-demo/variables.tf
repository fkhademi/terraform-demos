variable "controller_ip" {
  type        = string
  description = "Aviatrix Controller IP or FQDN"
}

variable "username" {
  type        = string
  description = "Aviatrix Controller Username"
  default     = "admin"
}

variable "password" {
  type        = string
  description = "Aviatrix Controller Password"
}

variable "env_name" {
  type        = string
  description = "Name for this environment"
  default     = "demo"
}

variable "aws_account_name" {
  type        = string
  description = "AWS Account Name"
  default     = "aws"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "eu-central-1"
}

variable "gcp_account_name" {
  type        = string
  description = "GCP Account Name"
  default     = "gcp"
}

variable "gcp_region" {
  type        = string
  description = "AWS Region"
  default     = "europe-west3"
}

variable "azure_account_name" {
  type        = string
  description = "Azure Account Name"
  default     = "azure-sub-1"
}

variable "azure_region" {
  type        = string
  description = "Azure Region"
  default     = "West Europe"
}


variable "ssh_key" {
  type        = string
  description = "Public ssh key for the test instances"
}
