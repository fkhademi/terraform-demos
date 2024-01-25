###################################### 
## AWS
######################################

# AWS Transit
module "aws_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.5.0"

  cloud           = "aws"
  account         = var.aws_account_name
  region          = var.aws_region
  name            = "${var.env_name}-aws-transit"
  cidr            = "172.17.0.0/23"
  ha_gw           = false
  local_as_number = 65518
}

# AWS Spoke
module "spoke1-aws" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.1"

  cloud      = "AWS"
  name       = "${var.env_name}-aws-spoke"
  region     = var.aws_region
  account    = var.aws_account_name
  transit_gw = module.aws_transit.transit_gateway.gw_name
  cidr       = "172.17.2.0/24"
  ha_gw      = false
}

###################################### 
## GCP
######################################

# GCP Transit
module "gcp_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.5.0"

  cloud           = "gcp"
  account         = var.gcp_account_name
  region          = var.gcp_region
  name            = "${var.env_name}-gcp-transit"
  cidr            = "172.18.0.0/23"
  ha_gw           = false
  local_as_number = 65519
}

# GCP Spoke
module "spoke1-gcp" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.1"

  cloud      = "gcp"
  name       = "${var.env_name}-gcp-spoke"
  region     = var.gcp_region
  account    = var.gcp_account_name
  transit_gw = module.gcp_transit.transit_gateway.gw_name
  cidr       = "172.18.2.0/24"
  ha_gw      = false
}

###################################### 
## GCP
######################################

# GCP Transit
module "azure_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.5.0"

  cloud           = "azure"
  account         = var.azure_account_name
  region          = var.azure_region
  name            = "${var.env_name}-azure-transit"
  cidr            = "172.19.0.0/23"
  ha_gw           = false
  local_as_number = 65520
}

# GCP Spoke
module "spoke1-azure" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.1"

  cloud      = "azure"
  name       = "${var.env_name}-azure-spoke"
  region     = var.azure_region
  account    = var.azure_account_name
  transit_gw = module.azure_transit.transit_gateway.gw_name
  cidr       = "172.19.2.0/24"
  ha_gw      = false
}
