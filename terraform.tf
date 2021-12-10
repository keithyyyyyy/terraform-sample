provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

# 1. create VPC
resource "aws_vpc" "terraform_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
    Name = "terraform_vpc"
  }
}

# 2. create internet gateway
resource "aws_internet_gateway" "terraform_gw" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "terraform_internet_gateway"
  }
}

# 3. create custom route table (optional)
resource "aws_route_table" "terraform_routeTable" {
  vpc_id = aws_vpc.terraform_vpc.id

  # default route
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_gw.id
  }

  # egress for packets to exit subnet
  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.terraform_gw.id
  }

  tags = {
    Name = "terraform_routeTable"
  }
}

# 4. create subnet
resource "aws_subnet" "terraform_subnet" {
  vpc_id = aws_vpc.terraform_vpc.id
  cidr_block = "10.0.1.0/24"

  # you can also specify AZ here
  # you might have to hardcode the AZ if you want your instances to deploy specifically in that AZ
  availability_zone =  "us-east-1a"

  tags = {
    Name = "terraform_subnet"
  }
}

# 5. associate subnet with route table
resource "aws_route_table_association" "terraform_routeTable_association" {
  subnet_id      = aws_subnet.terraform_subnet.id
  route_table_id = aws_route_table.terraform_routeTable.id
}

# 6. create security group to allow ports 20, 80, 443
resource "aws_security_group" "terraform_sg" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.terraform_vpc.id

  ingress {
    description      = "HTTP from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    # allow everyone to access
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    # allow everyone to access
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    # allow everyone to access
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    # -1 means any protocol
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. create network interface with an IP in the subnet that was created in step 4
resource "aws_network_interface" "terraform_network_interface" {
  subnet_id       = aws_subnet.terraform_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.terraform_sg.id]

}

# 8. assign elastic IP to network interface created in step 7
resource "aws_eip" "terraform_elastic_ip" {
  vpc                       = true
  network_interface         = aws_network_interface.terraform_network_interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.terraform_gw, aws_instance.terraform_ec2]
}

# 9. create ubuntu server and install/enable apache2
resource "aws_instance" "terraform_ec2" {
  ami = "ami-083654bd07b5da81d"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "terraform-keypair"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.terraform_network_interface.id
  }

  user_data = <<-EOF
		#!/bin/bash
    sudo apt-get update
		sudo apt-get install -y apache2
		sudo systemctl start apache2
		sudo systemctl enable apache2
		echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
	EOF

  tags = {
      Name = "terraform_ec2"
  }
}