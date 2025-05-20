provider "aws" {
    region = "us-east-1"
    access_key = "-----"
    secret_key = "-----"
}
terraform {
  backend "s3" {
    bucket         = "vnc"        # Replace with your existing S3 bucket name
    key            = "terraform/state/security-group.tfstate" # Path within the S3 bucket
    region         = "us-east-1"                        # AWS region where your S3 bucket is located
    encrypt        = true                               # Enable encryption for state file in S3
  }
}
resource "aws_vpc" "vpc" {
    enable_dns_hostnames = true
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "Custom_VPC"
    }
}

resource "aws_internet_gateway" "vpc_igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "igw"
    }
}

resource "aws_subnet" "vpc_private_subnet" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    tags = {
        Name = "private_subnet"
    }
    map_public_ip_on_launch = false
}

resource "aws_subnet" "vpc_public_subnet" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
    tags = {
        Name = "public_subnet"
    }
}

resource "aws_eip" "vpc_eip" {
    vpc = true
    tags = {
        Name = "eip"
    }
}

resource "aws_nat_gateway" "vpc_nat" {
    allocation_id = aws_eip.vpc_eip.id
    subnet_id = aws_subnet.vpc_public_subnet.id
    tags = {
        Name = "natgateway"
    }
    depends_on = [ aws_internet_gateway.vpc_igw ]
}

resource "aws_route_table" "vpc_private_routetable" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.vpc_nat.id
    }
    tags = {
        Name = "private_routetable"
    }
}

resource "aws_route_table" "vpc_public_routetable" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.vpc_igw.id
    }
    tags = {
        Name = "Public_routetable"
    }
}

resource "aws_route_table_association" "private_association" {
    subnet_id = aws_subnet.vpc_private_subnet.id
    route_table_id = aws_route_table.vpc_private_routetable.id
}

resource "aws_route_table_association" "public_association" {
    subnet_id = aws_subnet.vpc_public_subnet.id
    route_table_id = aws_route_table.vpc_public_routetable.id
}

resource "aws_security_group" "vpc_sg" {
    name = "My_sg"
    description = "for instance"
    vpc_id = aws_vpc.vpc.id

    ingress {
        protocol = "tcp"
        from_port = 22
        to_port = 22
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        protocol = "tcp"
        from_port = 80
        to_port = 80
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        protocol = "tcp"
        from_port = 8080
        to_port = 8080
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        protocol = "tcp"
        from_port = 9000
        to_port = 9000
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        protocol = "-1"
        from_port = 0
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
    }
}

data "aws_security_group" "existing_sg" {
    filters {
        name = "group-name"
        values = ["vnc"]
    }
}

resource "aws_ebs_volume" "ebs" {
    availability_zone = "us-east-1a"
    size = 10
    delete_on_termination = true
    tags = {
        Name = "hello"
    }
}

resource "aws_instance" "vpc_ec2" {
    ami = "-----"
    instance_type = "t2.micro"
    vpc_security_group_ids = [
        aws_security_group.existing_sg.id,
        aws_security_group.vpc_sg.id
    ] 
    count = 1
    key_name = "practi.pem"
    subnet_id = aws_subnet.vpc_public_subnet.id
    associate_public_ip_address = true
    tags = {
        Name = "Devserver"
    }
    root_block_device {
        size = 8
        volume_type = "gp2"
        delete_on_termination = true
    }
    
    depends_on = [
         aws_security_group.vpc_sg,
         aws_security_group.existing_sg 
    ]
    
}

resource "aws_volume_attachment" "mount_volume" {
    instance_id = aws_instance.vpc_ec2.id
    volume_id = aws_ebs_volume.ebs.id
}