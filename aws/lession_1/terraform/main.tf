terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.17.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
  }
}
# ======================== Init ========================
provider "aws" {
  region = "ap-southeast-1"
}

# ======================== VPC ========================
resource "aws_vpc" this {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "3tier-vpc"
  }
}

# ========== Subnets (1 vpc - N subnets) ==========
# 1 vpc - N subnets
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.this.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "private-app" {
  vpc_id = aws_vpc.this.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"
  tags = {
    Name = "private-app"
  }
}

resource "aws_subnet" "private-db" {
  vpc_id = aws_vpc.this.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-southeast-1c"
  tags = {
    Name = "private-db"
  }
}

# ============ Internet Gateway (1 VPC - 1 IGW)  ============
resource "aws_internet_gateway" this {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "3tier-igw"
  }
}

# ======================== Route Table ========================
# 1 VPC - N Route Table
# 1 Route Table - N Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ================= Security Group (1 VPC - N SG) =================
resource "aws_security_group" "sg-ec2-public" {
  vpc_id = aws_vpc.this.id
  # Inbound SSH (22)
  ingress {
    from_port = 22
    to_port = 22
    cidr_blocks = [ "0.0.0.0/0" ]
    protocol = "tcp"
  }
  # Inbound java-app (8080)
  ingress {
    from_port = 8080
    to_port = 8080
    cidr_blocks = [ "0.0.0.0/0" ]
    protocol = "tcp"
  }
  # Outbound internet (all)
  egress {
    from_port = 0
    to_port = 0
    cidr_blocks = [ "0.0.0.0/0" ]
    protocol = "-1"
  }
}

# ======================== EC2 ========================
# Create key SSH
resource "tls_private_key" "ec2-key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "ec2-key" {
  key_name = "ec2-key"
  public_key = tls_private_key.ec2-key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.ec2-key.private_key_pem
  filename = "${path.module}/ec2-key.pem"
  file_permission = "0600"
}

# Create EC2 instance
# 1 instance - N Security Group
resource "aws_instance" this {
  ami = "ami-05e0d9d655f80bc27"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public.id
  key_name = aws_key_pair.ec2-key.key_name
  vpc_security_group_ids = [ aws_security_group.sg-ec2-public.id ]
  associate_public_ip_address = true
  tags = {
    Name = "3tier-ec2-public"
  }
}

output "ec2-public_ip" {
  value = aws_instance.this.public_ip
}