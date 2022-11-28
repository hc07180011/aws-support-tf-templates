# https://docs.aws.amazon.com/network-firewall/latest/developerguide/arch-single-zone-igw.html

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

variable "aws-region" {}

provider "aws" {
  region = var.aws-region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-nfw-vpc"
  }
}

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "terraform-nfw-public1"
  }
}

resource "aws_subnet" "private1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "terraform-nfw-private1"
  }
}

resource "aws_networkfirewall_firewall_policy" "nfw-policy1" {
  name = "terraform-nfw-policy1"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:pass"]
  }
}

resource "aws_networkfirewall_firewall" "nfw1" {
  name                = "terraform-nfw1"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.nfw-policy1.arn
  vpc_id              = aws_vpc.main.id
  subnet_mapping {
    subnet_id = aws_subnet.public1.id
  }
}

data "aws_vpc_endpoint" "nfw1_vpce" {
  vpc_id = aws_vpc.main.id

  tags = {
    "AWSNetworkFirewallManaged" = "true"
    "Firewall"                  = aws_networkfirewall_firewall.nfw1.arn
  }

  depends_on = [
    aws_networkfirewall_firewall.nfw1
  ]
}

resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-nfw-igw1"
  }
}

resource "aws_route_table" "igw_rtb1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "10.0.2.0/24"
    vpc_endpoint_id = data.aws_vpc_endpoint.nfw1_vpce.id
  }

  tags = {
    Name = "terraform-nfw-igw-rtb1"
  }

  depends_on = [
    aws_networkfirewall_firewall.nfw1
  ]
}

resource "aws_route_table_association" "igw-rtb-association1" {
  gateway_id     = aws_internet_gateway.igw1.id
  route_table_id = aws_route_table.igw_rtb1.id
}

resource "aws_route_table" "public_rtb1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
  }

  tags = {
    Name = "terraform-nfw-public-rtb1"
  }
}

resource "aws_route_table_association" "public-rtb-association1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public_rtb1.id
}

resource "aws_route_table" "private_rtb1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = data.aws_vpc_endpoint.nfw1_vpce.id
  }

  tags = {
    Name = "terraform-nfw-private-rtb1"
  }

  depends_on = [
    aws_networkfirewall_firewall.nfw1
  ]
}

resource "aws_route_table_association" "private-rtb-association1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private_rtb1.id
}
