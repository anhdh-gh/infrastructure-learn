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

resource "aws_subnet" "public-2" {
  vpc_id = aws_vpc.this.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "ap-southeast-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-2"
  }
}

# ============ Internet Gateway (1 VPC - 1 IGW)  ============
resource "aws_internet_gateway" this {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "3tier-igw"
  }
}

# ======================== NAT Gateway (1 VPC - N NAT Gateway)========================
resource "aws_eip" "nat_public_ip" {
  domain = "vpc"
}

resource "aws_nat_gateway" this {
  subnet_id = aws_subnet.public.id
  allocation_id = aws_eip.nat_public_ip.id
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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
}

resource "aws_route_table_association" "private-app" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.private-app.id
}

# ======================== Security Group ========================
resource "aws_security_group" "ec2-sg" {
  vpc_id = aws_vpc.this.id

  # Outbound allow all (download docker, ...)
  egress {
    from_port = 0
    to_port = 0
    cidr_blocks = [ "0.0.0.0/0" ]
    protocol = "-1"
  }

  # Inbound allow ALB
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = [ aws_security_group.alb-sg.id ] # Cho phép traffic tới từ các instance có sg = alb-sg
  }
}

# ======================== EC2 ========================
# IAM role for SSM: Xác định AI được phép dùng role
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2_ssm_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com" # Cho phép service Amazon EC2 assume role này
      }
      Action = "sts:AssumeRole" # EC2 được phép "mượn" role này
    }]
  })
}

# Gắn quyền vào role: Role này được phép làm gì
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Tạo profile để gắn role vào EC2
resource "aws_iam_instance_profile" "ec2-profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# Create EC2 instance
# 1 instance - N Security Group
resource "aws_instance" this {
  ami = "ami-05e0d9d655f80bc27"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private-app.id
  iam_instance_profile = aws_iam_instance_profile.ec2-profile.name
  vpc_security_group_ids = [ aws_security_group.ec2-sg.id ]
  tags = {
    Name = "3tier-ec2-private"
  }
}

output "ec2_instance_id" {
  value = aws_instance.this.id
}

# ======================== Application Load Balancer (1 Vpc - N ALB) ========================
resource "aws_security_group" "alb-sg" {
  vpc_id = aws_vpc.this.id

  # Inbound allow 80
  ingress {
    from_port = 80
    to_port = 80
    protocol = "TCP"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  # Outbound allow when forward request to EC2 private (8080)
  egress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["10.0.2.0/24"] # private-app
  }
}

# ALB
resource "aws_lb" "this" {
  name = "alb"
  load_balancer_type = "application"
  subnets = [ aws_subnet.public.id, aws_subnet.public-2.id ] // ALB required 2 public subnet for HA
  security_groups = [ aws_security_group.alb-sg.id ]
}

resource "aws_lb_target_group" this {
  port = 8080
  protocol = "HTTP"
  vpc_id = aws_vpc.this.id
}

# ALB (listen 80) -> Target group (8080) -> Instance
resource "aws_alb_listener" listener {
  load_balancer_arn = aws_lb.this.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_target_group_attachment" "this" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id = aws_instance.this.id
  port = 8080
}

output "alb_dns" {
  value = aws_lb.this.dns_name
}