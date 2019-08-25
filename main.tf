/*
  This Terraform script will deploy 1 custom VPC with 1 private Subnet and 1 public Subnet.
   One private APP EC2 intance in the private Subnet and 1 public EC2 intance in the public subnet.
   The public EC2 intance will be used as Jumpbox or bastion host to allow SSH connection with the private instance.

Pierre Mathieu, 08/25/2019
*/
provider "aws" {
  region                  = "${var.region}"
  shared_credentials_file = "~/.aws/credentials"
  allowed_account_ids     = ["${values(var.aws_account)}"]
  profile                 = "terraform"
}


### Ref: https://access.redhat.com/solutions/15356
data "aws_ami" "latest_rhel" {
  most_recent = true

  filter {
    name   = "name"
   values = ["RHEL-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["309956199498"] # Canonical

}

// terraform  state information for all environments is stored in dev account
terraform {
  backend "s3" {
    bucket  = "wma-terraform-state"
    key     = "infra/terraform.tfstate"
    region  = "us-east-1"
    profile = "terraform"
    shared_credentials_file = "~/.aws/credentials"
  } 
}


## 1.Create a VPC with a private and public subnet. It is logically isolated from other virtual networks in the AWS Cloud.
## It will be used to launch AWS resources into a virtual network that will define
resource "aws_vpc" "wma_vpc" {
  cidr_block = "${var.vpc_cidr_block}"
  instance_tenancy = "${var.instance_tenancy}"

  tags {
    Name = "${var.vpc_tag}"
  }
}


#Private subnet creation to host all the non-internet facing instances (APP instances)
resource "aws_subnet" "private_subnet" {
  cidr_block = "${var.subnet_cidr["private_cidr_1"]}"
  vpc_id = "${aws_vpc.wma_vpc.id}"
  availability_zone = "${var.availability_zone["az1"]}"

  tags
  {
    Name = "WMA-Private-Subnet"
  }
}


#Public subnet creation to host internet facing instances ( Jumpbox/Bastion, LB, VPN)
resource "aws_subnet" "public_subnet" {
  cidr_block = "${var.subnet_cidr["public_cidr_1"]}"
  vpc_id = "${aws_vpc.wma_vpc.id}"
  availability_zone = "${var.availability_zone["az2"]}"
  map_public_ip_on_launch = true

  tags
  {
    Name = "WMA-Public-Subnet"
  }
}


#Internet Gateway to allow communication between instances in the VPC and the internet
resource "aws_internet_gateway" "wma_internet_gateway" {
  vpc_id = "${aws_vpc.wma_vpc.id}"

  tags
  {
    Name = "WMA Internet Gateway"
  }
}

# Create the Internet Access
# Find the existing main Route Table Resource for the current VPC
# Add a Route to the main root table for the VPC that directs Internet traffic 0.0.0.0/0 to IGW
resource "aws_route" "wma_vpc_internet_access" {
  route_table_id        = "${aws_vpc.wma_vpc.main_route_table_id}"
  destination_cidr_block = "${var.destination_cidr_block}"
  gateway_id             = "${aws_internet_gateway.wma_internet_gateway.id}"
} # end resource


#This Elastic IP will be used by the NAT gateway where both will depend on the same Internet gateway
resource "aws_eip" "nat_gw_eip" {
  vpc      = true
  depends_on = ["aws_internet_gateway.wma_internet_gateway"]
}

#Network Address Translation gateway to enable instances (APP) in a private subnet to connect to the internet or other AWS services
resource "aws_nat_gateway" "gw" {
  allocation_id = "${aws_eip.nat_gw_eip.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"

  depends_on = ["aws_internet_gateway.wma_internet_gateway"]

  tags = {
    Name = "WMA Nat-Gateway"
  }
}


# Create the Route Table to add set of rules (routes), that will be used to determine where network traffic is directed for private subnet
resource "aws_route_table" "wma_private_route_table" {
  vpc_id = "${aws_vpc.wma_vpc.id}"


  tags {
    Name = "WMA Route Table"
  }

}


# Create the Internet Access for private. It will let traffic from private instances to go out through the the NAT gateway
resource "aws_route" "wma_route_internet_access" {
  route_table_id = "${aws_route_table.wma_private_route_table.id}"
  destination_cidr_block = "${var.destination_cidr_block}"
  nat_gateway_id = "${aws_nat_gateway.gw.id}"

}

# Associate the Route Table to the Private Subnet
  resource "aws_route_table_association" "route_private_subnet" {
    subnet_id     = "${aws_subnet.private_subnet.id}"
    route_table_id = "${aws_route_table.wma_private_route_table.id}"
  }

#Associate the Route Table to the public Subnet
resource "aws_route_table_association" "route_public_subnet" {
  subnet_id     = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_vpc.wma_vpc.main_route_table_id}"
}

#Jumbox public SG. Ingress only on port 22 for incoming traffic but Egress to go anywhere (=0.0.0.0/0) from any port (=0)  using any protocol (=-1)
resource "aws_security_group" "jumpbox_public_access" {
  name        = "allow_public_access"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.wma_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    ## cidr_blocks = ["${var.home_ip}"] is my recommandation to limit the connection to an office or single IP
    cidr_blocks     = ["0.0.0.0/0"]  ## As per requirement, but dangerous :(
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


#App Security Group. Only egress is needed to go anywhere (=0.0.0.0/0) from any port (=0)  using any protocol (=-1)
resource "aws_security_group" "app_security_group" {
  name        = "app-sg"
  description = "Security group for App"
  vpc_id      = "${aws_vpc.wma_vpc.id}"

  tags {
      name =  "wma-app-sg"
  }

  egress {
    from_port       = 0
    to_port         = 0
      protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


#For Jumpbox to communicate with the private network
resource "aws_security_group_rule" "jumpbox_to_app" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.jumpbox_public_access.id}"
  security_group_id        = "${aws_security_group.app_security_group.id}"
}



#Create a APP instance which needs to be in the private subnet to be secure..
resource "aws_instance" "app-instance" {
  ami    = "${data.aws_ami.latest_rhel.id}"
  instance_type = "t2.micro"
  key_name = "${var.ssh-key}"
  subnet_id = "${aws_subnet.private_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.app_security_group.id}"]

  iam_instance_profile = "${aws_iam_instance_profile.ec2_to_S3_profile.id}"

  root_block_device {
    volume_size = 10
  }

  ebs_block_device {
    device_name =  "/dev/sdb"
    volume_size = 10
    encrypted = false
  }

  ebs_block_device {
    device_name =  "/dev/sdc"
    volume_size = 10
    encrypted = false
  }

  tags = {
    Name = "WMA Private Instance"
  }

}

#Create a Jumpbox/Bastion instance and assign both security groups to it..
resource "aws_instance" "jumpbox" {
  ami    = "${data.aws_ami.latest_rhel.id}"
  instance_type = "t2.micro"
  key_name = "${var.ssh-key}"
  subnet_id = "${aws_subnet.public_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.jumpbox_public_access.id}","${aws_security_group.app_security_group.id}"]

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "WMA Public Instance"
  }

}


#Create an EC2 IAM Role, Attach a policy to manipulate S3.
resource "aws_iam_role" "ec2_to_S3_role" {
  name = "ec2_to_S3_role"
  description = "S3 IAM Role for EC2"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    role-type = "ec2-access"
  }
}


#Create a instance profile attached to the Role
resource "aws_iam_instance_profile" "ec2_to_S3_profile" {
  name = "ec2_to_S3_profile"
  role = "${aws_iam_role.ec2_to_S3_role.id}"
}


#Create policy for the role. This will allow associate instance to have full access on all S3 buckets in the system.
resource "aws_iam_role_policy" "ec2_to_S3_policy" {
  name = "ec2_to_S3_policy"
  role = "${aws_iam_role.ec2_to_S3_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF

}

