variable "region" {
  description = "OCI home region"
}

variable "tenancy_ocid" {
  description = "Tenancy OCID"
}

variable "compartment_ocid" {
  description = "Compartment OCID to deploy into"
}

variable "user_ocid" {
  description = "User OCID for API auth"
}

variable "fingerprint" {
  description = "API key fingerprint"
}

variable "private_key_path" {
  description = "Path to API private key"
}

variable "ssh_public_key" {
  description = "SSH public key to inject"
}

variable "notify_email" {
  description = "Email for €1 budget alert"
}

# Networking
variable "vcn_ocid" {
  description = "Existing VCN OCID (leave blank to create)"
  default     = ""
}

variable "proxy_subnet_cidr" {
  description = "CIDR for proxy subnet"
  default     = "10.0.1.0/24"
}

variable "apps_subnet_cidr" {
  description = "CIDR for apps subnet"
  default     = "10.0.2.0/24"
}

# App sizing (Always‑Free pool: 4 OCPU / 24 GB total)
variable "app_instance_count" {
  description = "How many app VMs"
  default     = 1
}

variable "app_ocpus" {
  description = "OCPUs per app VM"
  default     = 1
}

variable "app_memory_gbs" {
  description = "RAM (GB) per app VM"
  default     = 6
}

variable "ad_index" {
  description = "Which availability domain to use (0, 1, or 2)"
  type        = number
  default     = 0
}