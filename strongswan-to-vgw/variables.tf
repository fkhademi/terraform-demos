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

variable "dns_zone" {
  type        = string
  default     = "avxlab.de"
  description = "Route53 Domain Name to update"
}

variable "aws_account_name" {
  type        = string
  description = "AWS Account Name"
  default     = "aws"
}

variable "azure_account_name" {
  type        = string
  description = "Azure Account Name"
  default     = "azure-sub-1"
}

variable "gcp_account_name" {
  type        = string
  description = "GCP Account Name"
  default     = "gcp-acct-1"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "eu-central-1"
}

variable "azure_region" {
  type        = string
  description = "Azure Region"
  default     = "West Europe"
}

variable "gcp_region" {
  type        = string
  description = "GCP Region"
  default     = "europe-west3"
}

variable "ssh_key" {
}

variable "env_name" {
  default = "demo"
}

variable "strongswan_env_name" {
  default = "strongswan"
}

variable "strongswan_vpc_cidr" {
  default = "10.0.0.0/24"
}

variable "strongswan_asn" {
  default = 65400
}

variable "vgw_asn" {
  default = 65300
}

variable "psk" {
  default = "mapleleafs"
}

variable "tunnel_subnet1" {
  default = "169.254.201.0/30"
}

variable "tunnel_subnet2" {
  default = "169.254.202.0/30"
}

variable "vgw_cidr" {
  default = "172.16.0.0/23"
}

variable "vgw_env_name" {
  default = "vgw"
}
