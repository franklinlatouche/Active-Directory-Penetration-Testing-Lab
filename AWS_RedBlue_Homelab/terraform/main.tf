data "aws_caller_identity" "current" {}

# 1. VPC
resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "RedBlue-Lab-VPC" }
}

# 2. Internet Gateway
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id
  tags   = { Name = "RedBlue-IGW" }
}

# 3. Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "RedBlue-Public-Subnet" }
}

# 4. Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }

  tags = { Name = "RedBlue-Public-RouteTable" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 5. Security Group — Kali + Windows
resource "aws_security_group" "main_sg" {
  name        = "RedBlue-Main-SG"
  description = "Management access and full internal subnet communication"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  ingress {
    description = "RDP from admin"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  ingress {
    description = "All internal subnet traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. Security Group — Ubuntu SIEM
resource "aws_security_group" "tools_sg" {
  name        = "RedBlue-SecurityTools-SG"
  description = "Splunk, Nessus, and internal forwarder traffic"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  ingress {
    description = "Splunk Web UI"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  ingress {
    description = "Nessus Web UI"
    from_port   = 8834
    to_port     = 8834
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  # Port 5901 (VNC) removed — access Splunk/Nessus UIs directly via browser.
  # For terminal GUI needs: ssh -L 5901:localhost:5901 ubuntu@<siem-ip>

  ingress {
    description = "Splunk Universal Forwarder receiver"
    from_port   = 9997
    to_port     = 9997
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. EC2 Instances
resource "aws_instance" "kali" {
  ami                    = var.ami_kali
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public_subnet.id
  key_name               = var.key_name
  private_ip             = "10.0.1.10"
  vpc_security_group_ids = [aws_security_group.main_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "Kali-Attacker"
    Role = "RedTeam"
  }
}

resource "aws_instance" "windows" {
  ami                    = var.ami_windows
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public_subnet.id
  key_name               = var.key_name
  private_ip             = "10.0.1.20"
  vpc_security_group_ids = [aws_security_group.main_sg.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "Windows-Target"
    Role = "Victim"
  }
}

resource "aws_instance" "ubuntu_siem" {
  ami                    = var.ami_ubuntu
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.public_subnet.id
  key_name               = var.key_name
  private_ip             = "10.0.1.30"
  vpc_security_group_ids = [aws_security_group.tools_sg.id]

  user_data = templatefile("${path.module}/../scripts/install_tools.sh", {
    splunk_password = var.splunk_password
    splunk_version  = var.splunk_version
    splunk_build    = var.splunk_build
    nessus_deb_url  = var.nessus_deb_url
  })

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "Security-Tools-SIEM"
    Role = "BlueTeam"
  }
}

# 8. VPC Flow Logs → CloudWatch (all traffic, 14-day retention)
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/redblue-lab/vpc-flow-logs"
  retention_in_days = 14
}

resource "aws_iam_role" "flow_logs" {
  name = "RedBlue-VPCFlowLogs-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "RedBlue-VPCFlowLogs-Policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "lab" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.lab_vpc.id
}

# 9. CloudTrail → S3 (bucket name uses account ID for global uniqueness)
resource "aws_s3_bucket" "trail" {
  bucket        = "redblue-lab-trail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "lab" {
  name                          = "redblue-lab-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  depends_on = [aws_s3_bucket_policy.trail]
}
