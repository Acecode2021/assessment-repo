provider "aws" {
  region = "eu-north-1"
}

# Use the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the Internet Gateway attached to the default VPC
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.100.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "localbuka-public-subnet"
  }
}

# Private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.101.0/24"
  availability_zone = "eu-north-1a"
  tags = {
    Name = "localbuka-private-subnet"
  }
}

# Route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = data.aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.default.id
  }
  tags = {
    Name = "localbuka-public-rt"
  }
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
# 7. Security Group for the API (EC2 instance)
resource "aws_security_group" "api_sg" {
  name        = "localbuka-api-sg"
  description = "Allow HTTP, HTTPS, and SSH to the API"
  vpc_id      = "vpc-04ea27b306c9371f9" # Default VPC

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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

  ingress {
    description = "Node API Port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "localbuka-api-sg"
  }
}

# 8. Security Group for the Database (RDS)
resource "aws_security_group" "db_sg" {
  name        = "localbuka-db-sg"
  description = "Allow PostgreSQL only from the API security group"
  vpc_id      = "vpc-04ea27b306c9371f9"

  ingress {
    description     = "PostgreSQL from API SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.api_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "localbuka-db-sg"
  }
}
# 9. SSH key pair
resource "aws_key_pair" "localbuka_key" {
  key_name   = "localbuka-key"
  public_key = file("~/.ssh/localbuka-key.pub")
}

# 10. Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# 11. EC2 instance running the LocalBuka API
resource "aws_instance" "localbuka_api" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.api_sg.id]
  key_name               = aws_key_pair.localbuka_key.key_name

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y docker git
    systemctl enable --now docker
    usermod -aG docker ec2-user
    git clone https://github.com/Acecode2021/localbuka-devepos.git /home/ec2-user/app
    cd /home/ec2-user/app
    docker build -t localbuka-api:local .
    docker run -d --restart always -p 3000:3000 -e PORT=3000 --name localbuka-api localbuka-api:local
  EOF

  tags = {
    Name = "localbuka-api-instance"
  }
}

output "ec2_public_ip" {
  value = aws_instance.localbuka_api.public_ip
}
# 12. DB Subnet Group (required for RDS in a VPC)
resource "aws_db_subnet_group" "localbuka_db_subnet_group" {
  name       = "localbuka-db-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet.id,
    aws_subnet.private_subnet_b.id
  ]

  tags = {
    Name = "localbuka-db-subnet-group"
  }
}

# 13. RDS PostgreSQL instance
resource "aws_db_instance" "localbuka_db" {
  identifier             = "localbuka-db"
  engine                 = "postgres"
  engine_version         = "15.18"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "localbuka"
  username               = "localbuka"
  password               =  "LocalbukaPass2026"

  db_subnet_group_name   = aws_db_subnet_group.localbuka_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "localbuka-db"
  }
}

output "db_endpoint" {
  value     = aws_db_instance.localbuka_db.endpoint
  sensitive = true
}
# 14. Second private subnet in a different AZ (required for RDS)
resource "aws_subnet" "private_subnet_b" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.102.0/24"
  availability_zone = "eu-north-1b"
  tags = {
    Name = "localbuka-private-subnet-b"
  }
}