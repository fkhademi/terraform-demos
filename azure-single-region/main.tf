# Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.env_name}-rg"
  location = var.azure_region
}

# Create Transit VPC and Transit Gateway
module "azure_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.5.0"

  cloud          = "azure"
  account        = var.azure_account_name
  region         = var.azure_region
  resource_group = azurerm_resource_group.rg.name
  name           = "${var.env_name}-transit"
  cidr           = "10.1.0.0/23"
  ha_gw          = false
}

#######################################################
# SPOKE1
#######################################################

# Create Spoke VNET
resource "azurerm_virtual_network" "spoke1" {
  name                = "${var.env_name}-spoke1-vnet"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.100.0.0/24"]
}

# Create a subnet for the Aviatrix Spoke Gateways
resource "azurerm_subnet" "spoke1-gw" {
  name                 = "${var.env_name}-spoke1-gw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = ["10.100.0.0/28"]
}

# Create a subnet for test VM
resource "azurerm_subnet" "spoke1-vm" {
  name                 = "${var.env_name}-spoke1-vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = ["10.100.0.128/25"]
}

# Create a Route Table for Spoke1
resource "azurerm_route_table" "spoke1-rt" {
  name                          = "${var.env_name}-spoke1-rt"
  location                      = var.azure_region
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name           = "route1"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }

  lifecycle {
    ignore_changes = [
      route
    ]
  }
}

# Subnet Route Table Association
resource "azurerm_subnet_route_table_association" "gw" {
  subnet_id      = azurerm_subnet.spoke1-gw.id
  route_table_id = azurerm_route_table.spoke1-rt.id
}

resource "azurerm_subnet_route_table_association" "vm" {
  subnet_id      = azurerm_subnet.spoke1-vm.id
  route_table_id = azurerm_route_table.spoke1-rt.id
}

module "spoke1" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.1"

  cloud            = "Azure"
  name             = "${var.env_name}-spoke1"
  region           = var.azure_region
  resource_group   = azurerm_resource_group.rg.name
  account          = var.azure_account_name
  transit_gw       = module.azure_transit.transit_gateway.gw_name
  use_existing_vpc = true
  vpc_id           = "${azurerm_virtual_network.spoke1.name}:${azurerm_resource_group.rg.name}"
  gw_subnet        = azurerm_subnet.spoke1-gw.address_prefixes[0]
  ha_gw            = false
}


#######################################################
# SPOKE2
#######################################################
module "spoke2" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.1"

  cloud            = "Azure"
  name             = "${var.env_name}-spoke2"
  region           = var.azure_region
  resource_group   = azurerm_resource_group.rg.name
  account          = var.azure_account_name
  transit_gw       = module.azure_transit.transit_gateway.gw_name
  cidr             = "10.200.0.0/24"
  use_existing_vpc = false
  ha_gw            = false
}

#######################################################
# TEST INSTANCES
#######################################################

module "spoke1-vm" {
  source = "git::https://github.com/fkhademi/terraform-azure-instance-module.git?ref=new-repo"

  name           = "${var.env_name}-spoke1-vm"
  region         = var.azure_region
  rg             = azurerm_resource_group.rg.name
  vnet           = azurerm_virtual_network.spoke1.name
  subnet         = azurerm_subnet.spoke1-vm.id
  ssh_key        = var.ssh_key
  public_ip      = true
  ubuntu_version = "22_04-lts-gen2"
  ubuntu_offer   = "0001-com-ubuntu-server-jammy"
}

module "spoke2-vm" {
  source = "git::https://github.com/fkhademi/terraform-azure-instance-module.git?ref=new-repo"

  name           = "${var.env_name}-spoke2-vm"
  region         = var.azure_region
  rg             = azurerm_resource_group.rg.name
  vnet           = module.spoke2.vpc.name
  subnet         = module.spoke2.vpc.public_subnets[0].subnet_id
  ssh_key        = var.ssh_key
  public_ip      = true
  ubuntu_version = "22_04-lts-gen2"
  ubuntu_offer   = "0001-com-ubuntu-server-jammy"
}

output "spoke1-public-ip" {
  value = module.spoke1-vm.public_ip.ip_address
}

output "spoke2-public-ip" {
  value = module.spoke2-vm.public_ip.ip_address
}
