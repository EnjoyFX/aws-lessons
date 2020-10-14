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
  region = var.region
}

variable "region" {
  default = "us-east-1"
}

variable "key_name" {
  default     = "ash-go2"
}

variable "bucket_name" {
  default = "aws-andy-test-001"
}

// VPC (Virtual Private Cloud)
// CIDR - Classless Inter-Domain Routing
resource "aws_vpc" "vpc_custom" {
  cidr_block = "10.0.0.0/16"
}

// Internet Gateway
resource "aws_internet_gateway" "igw_custom" {
  vpc_id = aws_vpc.vpc_custom.id
}

// Subnets
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc_custom.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.vpc_custom.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
}

resource "aws_subnet" "my-rds" {
  vpc_id                  = aws_vpc.vpc_custom.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "${var.region}c"
}

resource "aws_subnet" "my-alb" {
  vpc_id                  = aws_vpc.vpc_custom.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "${var.region}d"
  map_public_ip_on_launch = true
}

// Route tables
resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.vpc_custom.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_custom.id
  }
}

resource "aws_route_table" "rt_bastion" {
  vpc_id = aws_vpc.vpc_custom.id
}

resource "aws_route_table_association" "association_public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt_public.id
}

resource "aws_route_table_association" "association_private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.rt_bastion.id
}

// IAM Roles:
resource "aws_iam_role" "public" {
  name = "public"
  assume_role_policy = <<-EOF
  {
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : { "Service" : "ec2.amazonaws.com" },
        "Effect" : "Allow"
      }
    ]
  }
  EOF
}

// IAM role policy for public
resource "aws_iam_role_policy" "public" {
  name = "public"
  role = aws_iam_role.public.id
  policy = <<-EOF
  {
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : ["s3:*"],
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Action" : ["dynamodb:*"],
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Action" : ["sns:*"],
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Action" : ["sqs:*"],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_instance_profile" "public" {
  name = "public"
  role = aws_iam_role.public.name
}

resource "aws_iam_role" "private" {
  name = "private"
  assume_role_policy = <<-EOF
  {
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : { "Service" : "ec2.amazonaws.com" },
        "Effect" : "Allow"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "private" {
  name = "private"
  role = aws_iam_role.private.id

  policy = <<-EOF
  {
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : ["s3:*"],
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Action" : ["sns:*"],
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Action" : ["sqs:*"],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_instance_profile" "private" {
  name = "private"
  role = aws_iam_role.private.name
}

// Security groups
resource "aws_security_group" "bastion" {
  name   = "bastion"
  vpc_id = aws_vpc.vpc_custom.id
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "public_http" {
  name   = "public_http"
  vpc_id = aws_vpc.vpc_custom.id
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "public_ssh" {
  name   = "public_ssh"
  vpc_id = aws_vpc.vpc_custom.id
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = [aws_subnet.public.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private" {
  name   = "private"
  vpc_id = aws_vpc.vpc_custom.id
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = [aws_subnet.public.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "my-rds" {
  name        = "my-rds"
  vpc_id = aws_vpc.vpc_custom.id
  ingress {
    from_port   = 5432
    protocol    = "tcp"
    to_port     = 5432
    cidr_blocks = [aws_subnet.public.cidr_block, aws_subnet.my-alb.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// AutoScaling Group
resource "aws_autoscaling_group" "my-tf-asg" {
  name                 = "my-tf-asg"
  vpc_zone_identifier = [aws_subnet.public.id, aws_subnet.my-alb.id]
  max_size             = 2
  min_size             = 2
  launch_configuration = aws_launch_configuration.cfg.name
}

resource "aws_launch_configuration" "cfg" {
  name            = "cfg"
  image_id        = "ami-0c94855ba95c71c99"
  instance_type   = "t2.micro"
  key_name        = var.key_name
  security_groups = [
    aws_security_group.public_ssh.id,
    aws_security_group.public_http.id
  ]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.public.name
  user_data = <<-EOF
    #!/bin/bash
    sudo su
    yum update -y
    yum install -y httpd
    service httpd start
    chkconfig httpd on
    cd /var/www/html
    echo "<html><h1>Web interface for public subnet</h1></html>" > index.html
    yum install -y java-1.8.0-openjdk
    aws s3 cp s3://${var.bucket_name}/calc-0.0.1-SNAPSHOT.jar .
    java -jar calc-0.0.1-SNAPSHOT.jar
  EOF
}

// Bastion instance
resource "aws_instance" "bastion" {
  ami                         = "ami-00a9d4a05375b2763"
  instance_type               = "t2.micro"
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  source_dest_check           = false

  tags = {
    Name = "Bastion"
  }
}

// Private instance
resource "aws_instance" "private" {
  ami                  = "ami-0c94855ba95c71c99"
  iam_instance_profile = aws_iam_instance_profile.private.name
  instance_type        = "t2.micro"
  key_name             = var.key_name
  subnet_id            = aws_subnet.private.id
  vpc_security_group_ids = [
    aws_security_group.private.id
  ]
  user_data = <<-EOF
    #!/bin/bash
    sudo su
    yum update -y
    yum install -y java-1.8.0-openjdk
    aws s3 cp s3://${var.bucket_name}/persist3-0.0.1-SNAPSHOT.jar .
    RDS_HOST=${aws_db_instance.my-rds.address} java -jar persist3-0.0.1-SNAPSHOT.jar
  EOF

  tags = {
    Name = "Private"
  }

}

// Application load balancer
resource "aws_lb_target_group" "lb-tg" {
  name     = "lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_custom.id
  health_check {
    path = "/health"
  }
}

resource "aws_lb" "lb" {
  name               = "lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_http.id]
  subnets            = [aws_subnet.public.id, aws_subnet.my-alb.id]
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tg.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.my-tf-asg.name
  alb_target_group_arn   = aws_lb_target_group.lb-tg.arn
}

// DynamoDB with requested name:
resource "aws_dynamodb_table" "dynamo" {
  name           = "edu-lohika-training-aws-dynamodb" // required
  billing_mode   = "PROVISIONED" // optional, free-tier eligible
  read_capacity  = 20 // required if PROVISIONED selected
  write_capacity = 20 // required if PROVISIONED selected
  hash_key       = "UserName" // Required, forces new resource
  attribute {
    name = "UserName"
    type = "S"
  }
}

// RDS - Relational Database Service
resource "aws_db_subnet_group" "my-rds" {
  name       = "my-rds"
  subnet_ids = [aws_subnet.private.id, aws_subnet.my-rds.id]
}

resource "aws_db_instance" "my-rds" {
  allocated_storage      = 20 // allocated storage in Gb
  instance_class         = "db.t2.micro"
  storage_type           = "gp2" // optional, gp2 = general purpose SSD
  engine                 = "postgres"
  engine_version         = "11.5"
  port                   = 5432
  name                   = "EduLohikaTrainingAwsRds"
  username               = "rootuser"
  password               = "rootuser"
  vpc_security_group_ids = [aws_security_group.my-rds.id]
  skip_final_snapshot    = true // optional, default is false
  db_subnet_group_name   = aws_db_subnet_group.my-rds.name
}

// SQS - Simple Queue Service:
resource "aws_sqs_queue" "sqs_queue" {
  name = "edu-lohika-training-aws-sqs-queue"
}

// SNS - Simple Notification Service
resource "aws_sns_topic" "sns_topic" {
  name = "edu-lohika-training-aws-sns-topic"
}

// Output Values
output "dns_name" {
  value = aws_lb.lb.dns_name
  description = "print DNS name of load balancer"
}
