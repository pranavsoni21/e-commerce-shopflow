# Fetch subnet details to get its AZ
data "aws_subnet" "monitoring" {
  id = var.public_subnet_ids[0]
}

# EBS volume for EC2
resource "aws_ebs_volume" "monitoring" {
  availability_zone = data.aws_subnet.monitoring.availability_zone
  size              = 20
  encrypted         = true

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-monitoring-ebs"
  })
}

resource "aws_key_pair" "monitoring" {
  public_key = file("${path.root}/monitoring.pem.pub")
  key_name = "monitoring-key"
}

# EC2 for monitoring
resource "aws_instance" "monitoring" {
  ami                    = "ami-01a00762f46d584a1"
  instance_type          = "t3.small"
  subnet_id              = var.public_subnet_ids[0]
  availability_zone      = data.aws_subnet.monitoring.availability_zone
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  key_name = aws_key_pair.monitoring.key_name

  user_data_base64 = base64encode(<<-EOF
              #!/bin/bash
              set -e

              # Wait for EBS volume to attach
              sleep 10

              # Format the volume if not already formatted
              if ! sudo blkid /dev/nvme1n1; then
                sudo mkfs.ext4 /dev/nvme1n1
              fi

              # Create mount point
              sudo mkdir -p /data/prometheus

              # Mount the volume
              sudo mount /dev/nvme1n1 /data/prometheus

              # Add to fstab for persistent mounting
              echo "/dev/nvme1n1 /data/prometheus ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

              # Set permissions
              sudo chown ubuntu:ubuntu /data/prometheus
              EOF
  )

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-monitoring-ec2"
  })
}

resource "aws_volume_attachment" "monitoring" {
  device_name = "/dev/sdf"
  instance_id = aws_instance.monitoring.id
  volume_id   = aws_ebs_volume.monitoring.id
}

# Security Group
resource "aws_security_group" "monitoring" {
  name = "shopflow-monitoring-ec2-sg"
  vpc_id = var.vpc_id

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow services to send metrics at port 8000
  ingress {
    to_port     = 9090
    from_port   = 9090
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Allow ssh for remote access
  ingress {
    to_port     = 22
    from_port   = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    to_port = 3000
    from_port = 3000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


}

resource "aws_eip" "monitoring" {
  instance = aws_instance.monitoring.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-monitoring-eip"
  })
}





