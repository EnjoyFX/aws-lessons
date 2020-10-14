terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_autoscaling_group" "my-asg" {
  availability_zones   = ["us-east-1c"]
  name                 = "my-asg"
  max_size             = 2
  min_size             = 2
  desired_capacity     = 2
  force_delete         = true
  launch_configuration = aws_launch_configuration.my-lc.name
}

resource "aws_launch_configuration" "my-lc" {
  name          = "my-lc"
  image_id      = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"

  # Security group
  security_groups = [aws_security_group.my-sg.id]
  user_data = <<-EOF
		#! /bin/bash
    sudo su
    yum update -y
    yum install -y java-1.8.0-openjdk
    yum install -y httpd
    service httpd start
    chkconfig httpd on
    cd /var/www/html
    echo "<html><h1>This instance is visible</h1></html>" > index.html
	EOF
  key_name      = "ash-go2"
}

resource "aws_security_group" "my-sg" {
  name        = "my-sg"
  description = "Allowing HTTP and SSH from everywhere"

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
