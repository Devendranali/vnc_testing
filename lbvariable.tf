variable "aws_region" {
    type = string
    default = "us-east-1"
}

variable "access_key" {
    type = string
    default = "----"
} 

variable "secret_key" {
    type = string
    default = "----"
}

variable "vpc_cidr_block" {
    type = string
    default = "10.0.0.0/16"
}

variable "private_cidr_block" {
    type = string
    default = "10.0.1.0/24"
}

variable "private_zone" {
    type = string
    default = "us-east-1a"
}

variable "public_cidr_block" {
    type = string
    default = "10.0.2.0/24"
}

variable "public_zone" {
    type = string
    default = "us-east-1a"
}

variable "private_rt_cidr_block" {
    type = string
    default = "0.0.0.0/0"
}

variable "public_rt_cidr_block" {
    type = string
    default = "0.0.0.0/0"
} 

variable "sg_name" {
    type = string
    default = "My_sg"
}

variable "private_ami_id" {
    type = string
    default = "-------"
}

variable "instance_type" {
    type = string
    default = "t2.micro"
}

variable "key_name" {
    type = string
    default = "zero.pem"
}

variable "public_ami_id" {
    type = string
    default = "-------"
}

variable "instance_type1" {
    type = string
    default = "t2.micro"
}

variable "key_name1" {
    type = string
    default = "one.pem"
}


