
# Root Terraform Configuration - DevOps Stage 6 Infrastructure

# Terraform and Provider Requirements

terraform {
  required_version = ">= 1.0"                    # Minimum Terraform version

  required_providers {
    # AWS Provider - For cloud infrastructure
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"                         # AWS provider v5.x
    }

    # Local Provider - For generating local files (Ansible inventory)
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }

    # Null Provider - For running provisioners and scripts
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}


# Local Variables - Common Tags

locals {
  common_tags = {
    Project     = var.project_name               # Project identifier
    Environment = var.environment                # Environment (dev/staging/prod)
    ManagedBy   = "Terraform"                    # Infrastructure as Code tool
    DriftCheck  = "enabled"                      # Enable drift detection
    Owner       = var.owner_email                # Owner for notifications
  }
}


# Module: Networking

module "networking" {
  source = "./modules/networking"

  # Pass variables to networking module
  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr              # VPC IP range (e.g., 10.0.0.0/16)
  public_subnet_cidr = var.public_subnet_cidr    # Subnet IP range (e.g., 10.0.1.0/24)
  availability_zone  = var.availability_zone     # AZ for resource placement
  ssh_allowed_ips    = var.ssh_allowed_ips       # IPs allowed to SSH
  common_tags        = local.common_tags         # Apply common tags
}


# Module: Compute

module "compute" {
  source = "./modules/compute"

  # Pass variables to compute module
  project_name      = var.project_name
  instance_type     = var.instance_type          # EC2 instance size (t3.medium)
  subnet_id         = module.networking.public_subnet_id     # From networking module
  security_group_id = module.networking.security_group_id    # From networking module
  ssh_public_key    = var.ssh_public_key         # SSH public key content
  deploy_user       = var.deploy_user            # Deployment user name
  root_volume_size  = var.root_volume_size       # Root volume size in GB
  common_tags       = local.common_tags          # Apply common tags

  # Wait for networking to be ready before creating compute resources
  depends_on = [module.networking]
}


# Module: Provisioner

module "provisioner" {
  source = "./modules/provisioner"

  # Pass variables to provisioner module
  instance_id          = module.compute.instance_id          # From compute module
  instance_public_ip   = module.compute.instance_public_ip   # From compute module
  ssh_user             = var.ssh_user                        # Initial SSH user (ubuntu)
  ssh_private_key_path = var.ssh_private_key_path            # Path to SSH private key
  deploy_user          = var.deploy_user                     # Application deployment user
  domain_name          = var.domain_name                     # Application domain

  # Wait for compute resources to be ready before provisioning
  depends_on = [module.compute]
}
