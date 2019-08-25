variable "aws_account" {
  type    = "map"
  default =
  {
    "dev" = "put_dev_aws_number"
    "prod" = "put_prod_aws_number"
  }
}

variable "region" {
  default = "us-east-1"
}


#create a default CIDR block of 2^(32-16) = 65536 0f subnets and 2^(32-16) -2  = 65534 of IPs
# Ref: http://subnet-calculator.org/cidr.php
variable "vpc_cidr_block" {
  default = "10.10.0.0/16"
}


variable "instance_tenancy" {
  default = "default"
}

variable "vpc_tag" {
  default = "wma Assessment VPC"
}

variable "vpc_name" {
  default = "wma_vpc"
}


variable "subnet_cidr" {
  type = "map"
  default =
  {
    private_cidr_1 = "10.10.1.0/24"
    public_cidr_1  = "10.10.2.0/24"
    public_cidr_2  = "10.10.5.0/24"

    db_cidr_1 = "10.10.3.0/24"
    db_cidr_2 = "10.10.4.0/24"
  }

}

variable "availability_zone" {
  type = "map"
  default = {
    az1 = "us-east-1a"
    az2 = "us-east-1b"
    az3 = "us-east-1c"
    az4 = "uus-east-1d"
    az5 = "uus-east-1e"
    az6 = "uus-east-1f"
  }
}


variable "destination_cidr_block" {
  default = "0.0.0.0/0"
}


variable "home_ip" {
  default = "173.11.142.209/32"
}

variable "ssh-key" {
  default = "mwadeploykey"
}
