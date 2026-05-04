# Copyright IBM Corp. 2025, 2026

# EC2 instance module outputs

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.this.arn
}

output "instance_public_ip" {
  description = "Public IP address assigned to the instance, if applicable"
  value       = aws_instance.this.public_ip
}

output "instance_private_ip" {
  description = "Private IP address assigned to the instance"
  value       = aws_instance.this.private_ip
}

output "ami_id" {
  description = "ID of the AMI used for the instance"
  value       = aws_instance.this.ami
}


