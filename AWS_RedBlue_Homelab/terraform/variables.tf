variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "redblue-lab-keypair"
}

variable "admin_ip" {
  description = "Your public IP CIDR to restrict access (e.g., 203.0.113.50/32)"
  type        = string
}

variable "splunk_password" {
  description = "Admin password for Splunk Web UI (min 8 chars, must include uppercase, lowercase, digit)"
  type        = string
  sensitive   = true
}

variable "splunk_version" {
  description = "Splunk Enterprise version — find latest at splunk.com/en_us/download/splunk-enterprise.html"
  type        = string
  default     = "9.1.2"
}

variable "splunk_build" {
  description = "Splunk build hash — must match splunk_version exactly (visible in the download URL)"
  type        = string
  default     = "b6b9c8185839"
}

variable "nessus_deb_url" {
  description = "Nessus .deb download URL — get current URL from tenable.com/downloads/nessus"
  type        = string
  default     = "https://www.tenable.com/downloads/api/v1/public/pages/nessus/downloads/24057/Nessus-10.6.3-debian10_amd64.deb"
}

variable "ami_kali" {
  description = "Kali Linux AMI ID for your region — find in AWS Marketplace (search 'Kali Linux')"
  type        = string
}

variable "ami_windows" {
  description = "Windows Server 2022 Base AMI ID — find via EC2 console > AMIs > search 'Windows_Server-2022-English-Full-Base'"
  type        = string
}

variable "ami_ubuntu" {
  description = "Ubuntu 22.04 LTS AMI ID — find via: aws ec2 describe-images --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*' --query 'sort_by(Images,&CreationDate)[-1].ImageId'"
  type        = string
}
