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
  default     = "zdenko"
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
