data "aws_route53_zone" "pub" {
  name         = var.dns_zone
  private_zone = false
}

resource "aws_vpc" "strongswan" {
  cidr_block           = var.strongswan_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.strongswan_env_name}-vpc"
  }
}

resource "aws_internet_gateway" "strongswan" {
  vpc_id = aws_vpc.strongswan.id
  tags = {
    Name = "${var.strongswan_env_name}-igw"
  }
}

resource "aws_route_table" "strongswan" {
  vpc_id = aws_vpc.strongswan.id
  tags = {
    Name = "${var.strongswan_env_name}-rtb"
  }
}

resource "aws_route" "strongswan" {
  route_table_id         = aws_route_table.strongswan.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.strongswan.id
}

resource "aws_subnet" "strongswan" {
  vpc_id     = aws_vpc.strongswan.id
  cidr_block = var.strongswan_vpc_cidr
  tags       = { Name = "${var.strongswan_env_name}-subnet" }
}

resource "aws_route_table_association" "strongswan" {
  subnet_id      = aws_subnet.strongswan.id
  route_table_id = aws_route_table.strongswan.id
}

module "strongswan" {
  source    = "git::https://github.com/fkhademi/terraform-aws-instance-module.git?ref=custom-ubuntu"
  name      = var.strongswan_env_name
  region    = var.aws_region
  vpc_id    = aws_vpc.strongswan.id
  subnet_id = aws_subnet.strongswan.id
  ssh_key   = var.ssh_key
  user_data = templatefile("${path.module}/strongswan.sh",
    {
      psk                      = var.psk
      local_public_ip          = module.strongswan.eip.public_ip
      remote_public_ip         = aws_vpn_connection.vgw.tunnel1_address
      remote_public_ip2        = aws_vpn_connection.vgw.tunnel2_address
      local_tunnel1_interface  = cidrhost(var.tunnel_subnet1, 2)
      local_tunnel2_interface  = cidrhost(var.tunnel_subnet2, 2)
      remote_tunnel1_interface = cidrhost(var.tunnel_subnet1, 1)
      remote_tunnel2_interface = cidrhost(var.tunnel_subnet2, 1)
      local_asn                = var.strongswan_asn
      remote_asn               = var.vgw_asn
      local_prefix             = var.strongswan_vpc_cidr
  })
  public_ip      = true
  instance_size  = "t3.small"
  ubuntu_version = 22
}

resource "aws_route53_record" "strongswan" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "testgw.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.strongswan.eip.public_ip]
}

################# AWS SIDE

resource "aws_vpc" "vgw" {
  cidr_block           = var.vgw_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.vgw_env_name}-vpc"
  }
}

resource "aws_internet_gateway" "vgw" {
  vpc_id = aws_vpc.vgw.id
  tags = {
    Name = "${var.vgw_env_name}-igw"
  }
}

resource "aws_route_table" "vgw" {
  vpc_id = aws_vpc.vgw.id
  tags = {
    Name = "${var.vgw_env_name}-rtb"
  }
}

resource "aws_route" "vgw" {
  route_table_id         = aws_route_table.vgw.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vgw.id
}

resource "aws_subnet" "vgw" {
  vpc_id     = aws_vpc.vgw.id
  cidr_block = var.vgw_cidr
  tags       = { Name = "${var.vgw_env_name}-subnet" }
}

resource "aws_route_table_association" "vgw" {
  subnet_id      = aws_subnet.vgw.id
  route_table_id = aws_route_table.vgw.id
}

resource "aws_customer_gateway" "vgw" {
  bgp_asn    = var.strongswan_asn
  ip_address = module.strongswan.eip.public_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.strongswan_env_name}-cgw"
  }
}

resource "aws_vpn_gateway" "vgw" {
  vpc_id          = aws_vpc.vgw.id
  amazon_side_asn = var.vgw_asn

  tags = {
    Name = "${var.vgw_env_name}-vgw"
  }
}

resource "aws_vpn_connection" "vgw" {
  vpn_gateway_id        = aws_vpn_gateway.vgw.id
  customer_gateway_id   = aws_customer_gateway.vgw.id
  type                  = "ipsec.1"
  static_routes_only    = false
  tunnel1_inside_cidr   = var.tunnel_subnet1
  tunnel1_preshared_key = var.psk
  tunnel2_inside_cidr   = var.tunnel_subnet2
  tunnel2_preshared_key = var.psk
}

resource "aws_vpn_gateway_route_propagation" "vgw" {
  vpn_gateway_id = aws_vpn_gateway.vgw.id
  route_table_id = aws_route_table.vgw.id
}

module "cloud-vm" {
  source         = "git::https://github.com/fkhademi/terraform-aws-instance-module.git?ref=custom-ubuntu"
  name           = "test-vm"
  region         = var.aws_region
  vpc_id         = aws_vpc.vgw.id
  subnet_id      = aws_subnet.vgw.id
  ssh_key        = var.ssh_key
  user_data      = ""
  public_ip      = true
  instance_size  = "t3.small"
  ubuntu_version = 22
}

resource "aws_route53_record" "cloud-vm" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "testvm.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.cloud-vm.eip.public_ip]
}
