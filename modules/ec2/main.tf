# Copyright IBM Corp. 2025, 2026

# EC2 instance module main file

# Data source to fetch the latest Amazon Linux 2 AMI
# data "aws_ami" "amazon_linux_2" {
#   most_recent = true
#   owners      = ["amazon"]

#     filter {
#       name   = "name"
#       values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#     }

#     filter {
#       name   = "virtualization-type"
#       values = ["hvm"]
#     }
# }

# EC2 Instance resource
resource "aws_instance" "this" {
  ami           = "ami-0236922087fa98b6e" # Amazon Linux 2 AMI ID for us-east-1
  instance_type = var.instance_type
}
