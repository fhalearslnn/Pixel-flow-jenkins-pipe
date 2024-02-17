terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

backend "s3" {
  bucket = "jenkins-project-haley-backend"           # Replace with your S3
  key    = "backend/jenkins-backend-jenkins.tfstate" # Replace with your desired file name
  region = "us-west-1"                               # Replace with your AWS Region
}
provider "aws" {
  region = "us-east-1" # Replace with your AWS Region
}

variable "tags" {
  default = ["postgres", "nodejs", "react"]
}
variable "user" {
  default = "haley"
}


// Define security group for PostgreSQL
resource "aws_security_group" "prj-sec-grp" {
  name = "prj-sec-grp-${var.user}"
  tags = {
    "Name" = "prj-sec-grp"
  }
  description = "Security group for Jenkins Project"

  // Define ingress rules to allow traffic from Node.js EC2 instance and SSH from anywhere
  ingress {
    from_port   = 5432 // postgres server
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] // Allow traffic from anywhere
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] // Allow SSH from anywhere
  }
  ingress {
    from_port   = 5000 // nodejs server
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000 // react server
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Define egress rule to allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


// Define EC2 instances
resource "aws_instance" "managed" {
  ami                    = "ami-016eb5d644c333ccb" // Example AMI, replace with your desired AMI
  count                  = 3
  instance_type          = "t2.micro"
  key_name               = "firstkey" // Replace with your key pair name
  vpc_security_group_ids = [aws_security_group.prj-sec-grp.id]
  iam_instance_profile   = "jenkins-project-profile-${var.user}" // Created by Jenkins server
  tags = {
    Name        = "ansible_${element(var.tags, count.index)}"
    stack       = "ansible_project"
    environment = "development"
  }
  user_data = <<-EOF
            #! /bin/bash
            dnf update -y
            EOF
}

output "react_ip" {
  value = "http://${aws_instance.managed[2].public_ip}:3000/"

}
output "public_ip_node" {
  value = aws_instance.managed[1].public_ip
}
output "private_ip_postgres" {
  value = aws_instance.managed[0].private_ip
}
