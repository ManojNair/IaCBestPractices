variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production!
}

variable "allow_http" {
  description = "Allow HTTP traffic"
  type        = bool
  default     = false
}

variable "allow_https" {
  description = "Allow HTTPS traffic"
  type        = bool
  default     = false
}

variable "associate_with_subnet" {
  description = "Associate NSG with subnet"
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "Subnet ID for association"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
