# Azure Single Region Demo with DFW

Generic example to deploy an Aviatrix environment with Distributed Cloud Firewalling.

To test egress, log in to the Guacamole UI and you can jump to the spoke VM instances which have Egress policies applied to them

Terraform resources deployed
* Azure Resource Group
* Azure VNET
* Azure Subnet
* Azure Route Table
* Azure RT Association
* Azure Virtual Machine
* Aviatrix Transit VPC - Gateway
* Aviatrix Spoke VPC - Gateway

### Diagram
<img src="demo.png?raw=true">

### Output
* Public IP from Guacamole