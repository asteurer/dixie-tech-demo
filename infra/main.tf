#################################################################################
# Providers
#################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

#################################################################################
# Variables
#################################################################################

variable "aws_region" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "domain" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "cloudflare_api_token" {
  type = string
}

locals {
  name_tag = { "Name" = "${var.domain}" }
}

#################################################################################
# EC2 Instances
#################################################################################

#--------------------------------------------------------------------------------
# Misc
#--------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "prod" {
  key_name   = var.domain
  public_key = var.ssh_public_key

  tags = local.name_tag
}

#--------------------------------------------------------------------------------
# Networking
#--------------------------------------------------------------------------------

resource "aws_vpc" "prod" {
  cidr_block = "10.0.0.0/16"

  tags = local.name_tag
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.prod.id
  availability_zone = "${var.aws_region}a"
  cidr_block        = "10.0.0.0/24"

  tags = local.name_tag
}

resource "aws_internet_gateway" "prod" {
  vpc_id = aws_vpc.prod.id

  tags = local.name_tag

}

resource "aws_route_table" "prod" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod.id
  }

  tags = local.name_tag

}

resource "aws_route_table_association" "prod" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.prod.id
}

#--------------------------------------------------------------------------------
# SERVER: K3S Master Node
#--------------------------------------------------------------------------------

resource "aws_instance" "master_node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3a.small"
  key_name                    = aws_key_pair.prod.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.sg_master_node.id]

  tags = {
    "Name" = "${var.domain}-master-node"
  }
}

output "master_node_ip" {
  value = aws_instance.master_node.public_ip
}

resource "aws_security_group" "sg_master_node" {
  description = "security group for K3S master node"
  vpc_id      = aws_vpc.prod.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow for access to the KubeAPI Server
  ingress {
    description = "HTTP"
    from_port   = "6443"
    to_port     = "6443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "sg-${var.domain}-master-node"
  }
}

#################################################################################
# DNS Records
#################################################################################

resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = aws_instance.master_node.public_ip
  type    = "A"
  ttl     = 300

  depends_on = [aws_instance.master_node]
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = aws_instance.master_node.public_ip
  type    = "A"
  ttl     = 300

  depends_on = [aws_instance.master_node]
}