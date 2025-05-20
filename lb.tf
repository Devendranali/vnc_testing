provider "aws" {
    region = var.aws_region
    access_key = var.access_key
    secret_key = var.secret_key
}

resource "aws_vpc" "vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name = "my_vpc"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "my_igw"
    }
}

resource "aws_subnet" "private" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = var.private_cidr_block
    availability_zone = var.private_zone
    tags = {
        Name = "private_subnet"
    }
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = var.public_cidr_block
    availability_zone = var.public_zone
    tags = {
        Name = "public_subnet"
    }
    map_public_ip_on_launch = true
}

resource "aws_eip" "staticip" {
    vpc = true
    tags = {
        Name = "static"
    }
}

resource "aws_nat_gateway" "natgateway" {
    vpc_id = aws_vpc.vpc.id
    subnet_id = aws_subnet.public.id
    allocation_id = aws_eip.staticip.id
    tags = {
        Name = "natgateway"
    }
    depends_on = [aws_internet_gateway.igw, aws_eip.staticip]
}

resource "aws_route_table" "private_rt" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = var.private_rt_cidr_block
        gateway_id = aws_nat_gateway.natgateway.id
    }
    tags = {
        Name = "Private_routetable"
    }
}

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = var.public_rt_cidr_block
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "Public_routetable"
    }
}

resource "aws_route_table_association" "private_association" {
    subnet_id = aws_subnet.private.id
    route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "public_association" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "sg" {
    vpc_id = aws_vpc.vpc.id
    description = "loadbalancer_sg"
    name = var.sg_name

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["122.171.14.345/32"]
    }

      ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [aws_security_group.lb_sg.id]
    }

      ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        security_groups = [aws_security_group.lb_sg.id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "ec2" {
    ami = var.private_ami_id
    instance_type = var.instance_type
    subnet_id = aws_subnet.private.id
    vpc_security_group_ids = aws_security_group.sg.id
    key_name = var.key_name
    associate_public_ip_address = false
    availability_zone = var.private_zone

    tags = {
        Name = "private_ec2"
    }

    root_block_device {
        size = 8
        volume_type = "gp2"
        delete_on_termination = true
    }
    depends_on = [aws_security_group.sg]
}

resource "aws_instance" "ec2_1" {
    ami = var.public_ami_id
    instance_type = var.instance_type1
    subnet_id = aws_subnet.public.id
    vpc_security_group_ids = aws_security_group.sg.id
    key_name = var.key_name1
    associate_public_ip_address = true
    availability_zone = var.public_zone

    tags = {
        Name = "public_ec2"
    }

    root_block_device {
        size = 8
        volume_type = "gp2"
        delete_on_termination = true
    }
    depends_on = [aws_security_group.sg]
}

resource "aws_lb_target_group" "vpc_tg" {
    name = "my_tg"
    protocol = "HTTP"
    port = 80
    vpc_id = aws_vpc.vpc.id
    healthcheck {
        interval = 10
        path = "/"
        protocol = "HTTP"
        timeout = 5 
        healthy_threshold = 5
        unhealthy_threshold = 2
    }
    tags = {
        Name = "my_tg"
    }
}

resource "aws_lb_target_group_attachment" "ec2_attach" {
    target_group_arn = aws_lb_target_group.vpc_tg.arn
    target_id = aws_instance.ec2.id
    port = 80
}

resource "aws_lb_target_group_attachment" "ec2_1_attach" {
    target_group_arn = aws_lb_target_group.vpc_tg.arn
    target_id = aws_instance.ec2_1.id
    port = 80
}

resource "aws_security_group" "lb_sg" {
    name = "loadbalancer"
    vpc_id = aws_vpc.vpc.id
    description = "traficfirewall"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] 
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb" "vpc_lb" {
    load_balancer_type = "application"
    name = "lb"
    internal = false
    ip_address_type = "ipv4"
    vpc_id = aws_vpc.vpc.id
    subnets = [aws_subnet.private_subnet.id, aws_subnet.public_subnet.id]
    security_groups = [aws_security_group.lb_sg.id]
}

resource "aws_lb_listener" "vpc_lb_listener" {
    load_balancer_arn = aws_lb.vpc_lb.arn
    protocol = "HTTP"
    port = 80
    
    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.vpc_tg.arn
    }
}

resource "aws_launch_template" "awslt" {
    name = "my_lt"
    image_id = "ami_12345"
    instance_type = "t2.micro"
    
    user_data = << EOF
    sudo apt update -y
    sudo apt install httpd -y
    sudo systemctl start httpd 
    EOF

    key_name = "practi.pem"
    associate_public_ip_address = true
    security_groups = aws_security_group.sg.id
    
}

resource "aws_autoscalling_group" "sh_asg" {
    desired_capacity = 1
    max_size = 5
    min_size =2
    target_group_arn = [aws_lb_target_group.vpc_tg.arn]
    vpc_zone_identifier = [aws_subnet.private_subnet, aws_subnet.public_subnet]
    launch_template {
        id = aws_launch_template.awslt.id
        version = "latest"
    }

}

