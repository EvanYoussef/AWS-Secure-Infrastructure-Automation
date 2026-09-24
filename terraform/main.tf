resource "aws_iam_role" "ec2_ssm_role" {
  name = "DevSecOps-EC2-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    ManagedBy = "Terraform"
    Project   = "AWS-Secure-Infrastructure-Automation"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "DevSecOps-EC2-Instance-Profile"
  role = aws_iam_role.ec2_ssm_role.name
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "devsecops_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "DevSecOps-VPC"
    ManagedBy = "Terraform"
  }
}

# Lab exception: public IP assignment enables outbound AWS connectivity
# without adding NAT Gateway/VPC endpoint costs.
# No inbound security group rules are permitted.
#trivy:ignore:AWS-0164
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.devsecops_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name      = "DevSecOps-Public-Subnet"
    ManagedBy = "Terraform"
  }
}

resource "aws_internet_gateway" "devsecops_igw" {
  vpc_id = aws_vpc.devsecops_vpc.id

  tags = {
    Name = "DevSecOps-Internet-Gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.devsecops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devsecops_igw.id
  }

  tags = {
    Name = "DevSecOps-Public-Route-Table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Lab exception: outbound HTTPS is required for AWS Systems Manager.
# Production design would use private VPC endpoints for SSM.
#trivy:ignore:AWS-0104
resource "aws_security_group" "devsecops_sg" {
  name        = "devsecops-ec2-sg"
  description = "Security group for DevSecOps EC2 instance"
  vpc_id      = aws_vpc.devsecops_vpc.id

  egress {
    description = "Allow outbound HTTPS for aws service communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DevSecOps-EC2-Security-Group"
  }
}

resource "aws_instance" "devsecops_server" {
  ami                         = "ami-0b5358cc8c5df0b02"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.devsecops_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name        = "DevSecOps-Terraform-Server"
    Environment = "Development"
    Project     = "AWS-Secure-Infrastructure-Automation"
    ManagedBy   = "Terraform"
    Deployment  = "Github-Actions-CD"
  }
}
resource "aws_instance" "private_ip_address" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.devsecops_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name        = "DevSecOps-Private-Test-Server"
    Environment = "Development"
    Project     = "AWS-Secure-Infrastructure-Automation"
    ManagedBy   = "Terraform"
    Deployment  = "Github-Actions-CD"
  }
}
