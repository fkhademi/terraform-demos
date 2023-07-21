# Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.env_name}-rg"
  location = var.azure_region
}

# Create Transit VPC and Transit Gateway
module "azure_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.5.1"

  cloud          = "azure"
  account        = var.azure_account_name
  region         = var.azure_region
  resource_group = azurerm_resource_group.rg.name
  name           = "${var.env_name}-transit"
  cidr           = "10.1.0.0/23"
  ha_gw          = false
  insane_mode    = true
  instance_size  = "Standard_D3_v2"
}

#######################################################
# SPOKE1
#######################################################

module "spoke1" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.3"

  cloud            = "Azure"
  name             = "${var.env_name}-spoke1"
  region           = var.azure_region
  resource_group   = azurerm_resource_group.rg.name
  account          = var.azure_account_name
  transit_gw       = module.azure_transit.transit_gateway.gw_name
  instance_size    = "Standard_B2ms"
  cidr             = "10.100.0.0/24"
  use_existing_vpc = false
  ha_gw            = false
  single_ip_snat   = true
}


#######################################################
# SPOKE2
#######################################################
module "spoke2" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.3"

  cloud            = "Azure"
  name             = "${var.env_name}-spoke2"
  region           = var.azure_region
  resource_group   = azurerm_resource_group.rg.name
  account          = var.azure_account_name
  transit_gw       = module.azure_transit.transit_gateway.gw_name
  instance_size    = "Standard_B2ms"
  cidr             = "10.200.0.0/24"
  use_existing_vpc = false
  ha_gw            = false
  single_ip_snat   = true
}

#######################################################
# TEST INSTANCES
#######################################################

# Ubuntu 22 Guacamole
module "guac" {
  source         = "git::https://github.com/fkhademi/terraform-azure-instance-module.git?ref=new-repo"
  name           = "guac-vm"
  region         = var.azure_region
  rg             = azurerm_resource_group.rg.name
  vnet           = module.spoke1.vpc.name
  subnet         = module.spoke1.vpc.public_subnets[0].subnet_id
  ssh_key        = var.ssh_key
  public_ip      = true
  instance_size  = "Standard_B2ms"
  ubuntu_version = "22_04-lts-gen2"
  ubuntu_offer   = "0001-com-ubuntu-server-jammy"
  cloud_init_data = templatefile("${path.module}/guacamole_u22.sh",
    {
      username  = "demo"
      password  = var.linux_password
      hostname  = "guacamole"
      public_ip = module.guac.public_ip.ip_address
      host1     = module.spoke1-vm.nic.private_ip_address
      host2     = module.spoke2-vm.nic.private_ip_address
  })
}

module "spoke1-vm" {
  source = "git::https://github.com/fkhademi/terraform-azure-instance-module.git?ref=new-repo"

  name           = "${var.env_name}-spoke1-vm"
  region         = var.azure_region
  rg             = azurerm_resource_group.rg.name
  vnet           = module.spoke1.vpc.name
  subnet         = module.spoke1.vpc.private_subnets[0].subnet_id
  ssh_key        = var.ssh_key
  public_ip      = false
  ubuntu_version = "22_04-lts-gen2"
  ubuntu_offer   = "0001-com-ubuntu-server-jammy"
  cloud_init_data = templatefile("${path.module}/egress.sh",
    {
      username = "demo"
      password = var.linux_password
      hostname = "spoke1-vm"
  })
}

module "spoke2-vm" {
  source = "git::https://github.com/fkhademi/terraform-azure-instance-module.git?ref=new-repo"

  name           = "${var.env_name}-spoke2-vm"
  region         = var.azure_region
  rg             = azurerm_resource_group.rg.name
  vnet           = module.spoke2.vpc.name
  subnet         = module.spoke2.vpc.private_subnets[0].subnet_id
  ssh_key        = var.ssh_key
  public_ip      = false
  ubuntu_version = "22_04-lts-gen2"
  ubuntu_offer   = "0001-com-ubuntu-server-jammy"
  cloud_init_data = templatefile("${path.module}/egress.sh",
    {
      username = "demo"
      password = var.linux_password
      hostname = "spoke2-vm"
  })
}

output "guacamole" {
  value = module.guac.public_ip.ip_address
}

########################################
# DFW STUFF
########################################

resource "aviatrix_distributed_firewalling_config" "default" {
  enable_distributed_firewalling = true
}

variable "smartgroup_any" {
  default = "def000ad-0000-0000-0000-000000000000"
}

variable "smartgroup_internet" {
  default = "def000ad-0000-0000-0000-000000000001"
}

# Create an Aviatrix Smart Group
resource "aviatrix_smart_group" "guac" {
  name = "GUAC-VM"
  selector {
    match_expressions {
      cidr = "${module.guac.nic.private_ip_address}/32"
    }
  }
}

resource "aviatrix_smart_group" "spoke1" {
  name = "SPOKE1-VM"
  selector {
    match_expressions {
      cidr = "${module.spoke1-vm.nic.private_ip_address}/32"
    }
    # match_expressions {
    #   type         = "vm"
    #   account_name = var.azure_account_name
    #   region       = var.azure_region
    #   tags = {
    #     Name = "${var.env_name}-spoke1-vm-srv"
    #   }
    # }
  }
}

resource "aviatrix_smart_group" "spoke2" {
  name = "SPOKE2-VM"
  selector {
    match_expressions {
      cidr = module.spoke2.vpc.cidr
    }
  }
}

resource "aviatrix_web_group" "spoke1-fqdns" {
  name = "SPOKE1-ALLOWED-FQDNS"
  selector {
    match_expressions {
      snifilter = "mihai.tech"
    }
    match_expressions {
      snifilter = "doon.io"
    }
    match_expressions {
      snifilter = "google.ca"
    }
  }
}

resource "aviatrix_web_group" "spoke2-fqdns" {
  name = "SPOKE2-ALLOWED-FQDNS"
  selector {
    match_expressions {
      snifilter = "ubuntu.com"
    }
    match_expressions {
      snifilter = "github.com"
    }
    match_expressions {
      snifilter = "mercedes-benz.com"
    }
  }
}

resource "aviatrix_distributed_firewalling_policy_list" "guac" {
  policies {
    name     = "GUAC-REMOTEACCESS"
    action   = "PERMIT"
    priority = 1
    protocol = "TCP"
    logging  = true
    watch    = false
    src_smart_groups = [
      aviatrix_smart_group.guac.uuid
    ]
    dst_smart_groups = [
      aviatrix_smart_group.spoke1.uuid,
      aviatrix_smart_group.spoke2.uuid
    ]
  }

  policies {
    name     = "SPOKE1-INTERNET"
    action   = "PERMIT"
    priority = 20000
    protocol = "ANY"
    logging  = true
    watch    = false
    src_smart_groups = [
      aviatrix_smart_group.spoke1.uuid
    ]
    dst_smart_groups = [
      var.smartgroup_internet
    ]
    web_groups = [
      aviatrix_web_group.spoke1-fqdns.uuid
    ]
  }

  policies {
    name     = "SPOKE2-INTERNET"
    action   = "PERMIT"
    priority = 20001
    protocol = "ANY"
    logging  = true
    watch    = false
    src_smart_groups = [
      aviatrix_smart_group.spoke2.uuid
    ]
    dst_smart_groups = [
      var.smartgroup_internet
    ]
    web_groups = [
      aviatrix_web_group.spoke2-fqdns.uuid
    ]
  }

  depends_on = [aviatrix_distributed_firewalling_config.default]
}
