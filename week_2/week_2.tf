resource "aws_iam_role_policy" "s3_policy" {
  name = "s3_policy"
  role = aws_iam_role.root_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "root_role" {
  name = "root_role"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "instance_profile"
  role = aws_iam_role.root_role.name
}

resource "aws_security_group" "default" {
  name        = "aws_security_group"
  description = "Allowing SSH/HTTP from everywhere"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_instance" "aws_instance" {
  key_name      = "ash-go2"
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  vpc_security_group_ids = [aws_security_group.default.id]
  user_data = <<-EOF
		#! /bin/bash
    sudo su
    yum update -y
    aws s3 cp s3://aws-andy-test-001/the_file.txt '/home/ec2-user/the_file.txt'
	EOF
}
