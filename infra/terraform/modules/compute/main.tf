
# Compute Module - EC2 Instance, SSH Key, Elastic IP

data "aws_ami" "ubuntu" {
  most_recent = true                             # Get the latest version
  owners      = ["099720109477"]                 # Canonical (Ubuntu official)

  # Filter: Ubuntu 22.04 (Jammy Jellyfish) HVM SSD images
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  # Filter: Hardware Virtual Machine type
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# SSH Key Pair

resource "aws_key_pair" "app_key" {
  key_name   = "${var.project_name}-key"         # Unique key name
  public_key = var.ssh_public_key                # Your SSH public key content

  tags = var.common_tags
}


# EC2 Instance - Application Server

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id           # Latest Ubuntu 22.04
  instance_type          = var.instance_type                # t2.medium (4GB RAM)
  subnet_id              = var.subnet_id                    # Place in public subnet
  vpc_security_group_ids = [var.security_group_id]          # Attach security group
  key_name               = aws_key_pair.app_key.key_name    # SSH key for access


  # User Data Script

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system packages
              apt-get update
              apt-get upgrade -y
              
              # Install Python3 and pip (required for Ansible)
              apt-get install -y python3 python3-pip
              
              # Create deployment user with home directory and bash shell
              useradd -m -s /bin/bash ${var.deploy_user}
              
              # Add deployment user to sudo group
              usermod -aG sudo ${var.deploy_user}
              
              # Grant passwordless sudo privileges
              echo "${var.deploy_user} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
              
              # Setup SSH access for deployment user
              mkdir -p /home/${var.deploy_user}/.ssh
              
              # Copy SSH authorized keys from ubuntu user
              cp /home/ubuntu/.ssh/authorized_keys /home/${var.deploy_user}/.ssh/
              
              # Set proper ownership and permissions
              chown -R ${var.deploy_user}:${var.deploy_user} /home/${var.deploy_user}/.ssh
              chmod 700 /home/${var.deploy_user}/.ssh
              chmod 600 /home/${var.deploy_user}/.ssh/authorized_keys
              
              # Signal completion
              echo "Instance ready for Ansible" > /tmp/user_data_complete
              EOF


  # Root Volume Configuration

  root_block_device {
    volume_size           = var.root_volume_size  # Size in GB (default: 30GB)
    volume_type           = "gp3"                 # General Purpose SSD v3 (latest)
    delete_on_termination = true                  # Auto-delete on instance termination
    encrypted             = true                  # Encrypt data at rest

    tags = merge(var.common_tags, {
      Name = "${var.project_name}-root-volume"
    })
  }


  # Lifecycle Configuration - Idempotency

  lifecycle {
    ignore_changes = [user_data]                 # Don't recreate if user_data changes
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-app-server"
  })
}


# Elastic IP - Static Public IP

resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id          # Associate with our instance
  domain   = "vpc"                               # VPC-scoped EIP (not EC2-Classic)

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-eip"
  })
}


# Wait for Instance Initialization

resource "null_resource" "wait_for_instance" {
  depends_on = [aws_instance.app_server]

  provisioner "local-exec" {
    command = "sleep 60"                         # Wait 60 seconds
  }
}
