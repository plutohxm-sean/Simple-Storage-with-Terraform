terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

resource "aws_s3_bucket" "file_storage" {
  bucket_prefix = "terraform-demo-"
  force_destroy = true
  tags = {
    Name = "Terraform Demo Storage"
    Lab  = "Simple File Storage"
  }
}

resource "aws_s3_bucket_public_access_block" "file_storage" {
  bucket                  = aws_s3_bucket.file_storage.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "file_storage" {
  bucket = aws_s3_bucket.file_storage.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.file_storage.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.file_storage]
}

resource "aws_security_group" "web_server" {
  name_prefix = "terraform-demo-web-"
  description = "Security group for web server"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "Terraform Demo Web SG" }
}

resource "aws_iam_role" "ec2_role" {
  name_prefix = "terraform-demo-ec2-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name_prefix = "s3-access-"
  role        = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket"]
      Resource = [
        aws_s3_bucket.file_storage.arn,
        "${aws_s3_bucket.file_storage.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "terraform-demo-"
  role        = aws_iam_role.ec2_role.name
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_server.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    bucket_name = aws_s3_bucket.file_storage.bucket
    aws_region  = "us-west-1"
  }))
  tags = {
    Name = "Terraform Demo Web Server"
    Lab  = "Simple File Storage"
  }
}

output "website_url" {
  description = "Website URL"
  value       = "http://${aws_instance.web_server.public_dns}"
}

output "s3_bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.file_storage.bucket
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.web_server.id
}
