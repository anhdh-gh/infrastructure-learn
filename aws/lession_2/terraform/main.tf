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
  depends_on = [ aws_internet_gateway.this ]
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

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public-2.id
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
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"
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

# Tạo profile để gắn role vào EC2
resource "aws_iam_instance_profile" "ec2-profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_role.name
}

# Gắn quyền vào role: Role này được phép làm gì
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "dynamodb" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Create EC2 instance
# 1 instance - N Security Group
# resource "aws_instance" this {
#   ami = "ami-05e0d9d655f80bc27"
#   instance_type = "t2.micro"
#   subnet_id = aws_subnet.private-app.id
#   iam_instance_profile = aws_iam_instance_profile.ec2-profile.name
#   vpc_security_group_ids = [ aws_security_group.ec2-sg.id ]
#   depends_on = [ aws_nat_gateway.this ]
#   tags = {
#     Name = "3tier-ec2-private"
#   }
# }

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

output "alb_dns" {
  value = aws_lb.this.dns_name
}

# ======================== DynamoDB ========================
resource "aws_dynamodb_table" "users" {
  name = "users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "user_id"
  attribute {
    name = "user_id"
    type = "S"
  }
  tags = {
    Name = "users-table"
  }
}

# Tạo VPC endpoint: Đường kết nối từ EC2 tới dynamodb
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id = aws_vpc.this.id
  service_name = "com.amazonaws.ap-southeast-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [ aws_route_table.private.id ]
}

# ======================== Amazon Machine Images ========================
# resource "time_sleep" "wait" {
#   depends_on = [aws_instance.this.id]
#   create_duration = "120s"
# }

# resource "aws_ami_from_instance" "ec2-image" {
#   name               = "ec2-image"
#   source_instance_id = aws_instance.this.id
#   # depends_on = [time_sleep.wait]
# }

# ======================== Auto Scaling Group ========================
resource "aws_launch_template" "app" {
  name_prefix   = "app-template"
  image_id      = "ami-01241553410ff7760"
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2-profile.name
  }

  vpc_security_group_ids = [
    aws_security_group.ec2-sg.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash

    # Update system
    yum update -y

    # Install Docker
    amazon-linux-extras install docker -y

    # Start Docker
    systemctl start docker
    systemctl enable docker

    # Add ec2-user to docker group
    usermod -aG docker ec2-user

    # Wait Docker ready
    sleep 10

    # Pull image
    docker pull anhdhdocker/java-springboot-service:latest

    # Remove old container if exists
    docker rm -f springboot-app || true

    # Run new container
    docker run -d \
      --name springboot-app \
      -p 8080:8080 \
      anhdhdocker/java-springboot-service:latest

    echo "Application started on port 8080"
  EOF
  )
}

resource "aws_autoscaling_group" "app" {
  desired_capacity = 1
  max_size = 2
  min_size = 1
  launch_template {
    id = aws_launch_template.app.id
    version = "$Latest"
  }
  vpc_zone_identifier = [ aws_subnet.private-app.id ] # Subnet mà EC2 sẽ tạo
  target_group_arns = [ aws_lb_target_group.this.arn ] # Attach vào ALB
  health_check_type = "EC2" # ELB - Check health qua ALB, EC2 - Check sống/chết
}

# Scale up
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu_high"
  comparison_operator = "GreaterThanThreshold"
  threshold = 70
  evaluation_periods = 2 # CPU > 70% trong 2 phút liên tiếp → alarm kích hoạt
  period = 60
  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  statistic   = "Average"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

# Scale down
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "cpu-low"
  comparison_operator = "LessThanThreshold"
  threshold           = 30
  evaluation_periods = 2
  period             = 60
  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  statistic   = "Average"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}

# ======================== API Gateway ========================
# Client -> API Gateway -> ALB -> EC2 (Spring Boot)
resource "aws_apigatewayv2_api" "http_api" {
  name = "http-api"
  protocol_type = "HTTP"
}

# API GW -> ALB
resource "aws_apigatewayv2_integration" "alb_integration" {
  api_id = aws_apigatewayv2_api.http_api.id
  integration_type = "HTTP_PROXY"
  integration_uri = "http://${aws_lb.this.dns_name}"
  integration_method = "ANY"
  payload_format_version = "1.0"
}

# Map path
resource "aws_apigatewayv2_route" "default" {
  api_id = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /{proxy+}"
  target = "integrations/${aws_apigatewayv2_integration.alb_integration.id}"
}

# Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.http_api.id
  name = "$default"
  auto_deploy = true
}