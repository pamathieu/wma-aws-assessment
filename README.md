# aws -  Sample Virtual Private Cloud along with services such as EC2 instances in public and private subnets
WMA AWS Assessment in to parts (PART A and PART B)

                                                  PART A
The Terraform scripts (maint.tf and variables.tf) will deploy 1 custom VPC with 1 private Subnet and 1 public Subnet.
   1 private APP EC2 intance in the private Subnet and 1 public EC2 instance in the public subnet.
   The public EC2 instance will be used as a Jumpbox or a Bastion host to allow SSH connections with the private instance.
   
To enssure the security of the VPC the following will be done:
   1) Creation of a private subnet to host all the non-internet facing instances (APP instances).
   2) Creation of a public subnet to host all internet facing instances (Jumpbox/Bastion, LB, VPN).
   3) Creation of an Internet Gateway (IGW) to allow communication between instances in the VPC and the internet.
   4) Creation of a Route in the main root table for the VPC that directs Internet traffic 0.0.0.0/0 to IGW
   5) Creation of an Elastic IP address (EIP) to be used by the NAT gateway where both will depend on the same Internet gateway.
   6) Creation of a Network Address Translation (NAT) gateway to enable instances (APP) in the private subnet to connect to the internet or other AWS services.
   7) Creation of a Route Table to add set of rules (routes), that will be used to determine where network traffic is directed from and to the public subnet.
   8) Creation of a Route to create the Internet Access for private. It will let traffic from private instances to go out through the the NAT gateway.
   9) Association of the Route Table to the Private Subnet.
   10) Association of the Route Table to the Public Subnet.
   11) Creation of a Security group for the Jumpbox/Bastion host. Ingress (only on port 22) for incoming SSH traffic, but Egress to go anywhere (=0.0.0.0/0) from any ports (=0) using any protocols (=-1).
   12) Creation of a Security group for the private App instance. Only egress is needed to go anywhere (=0.0.0.0/0) from any port (=0)  using any protocol (=-1), used mostly relevnt for server updates and upgrades.
   13) Creation of a Security group Rule for the Jumpbox to communicate with the private instances (App)
   14) Creation of an APP instance which needs to be in the private subnet to be secure by being associated to the Security Group.
       We will use the latest RHEL with a root volume of 10 GB, and 2 additional of 10 GB volumes on /dev/sdb and /dev/sdc devices.
   15) Creation of a Jumpbox/Bastion instance and assign both security groups to it.We will use the latest RHEL with a root volume of 10 GB with no additonal volumes.
   16) Creation of an EC2 IAM Role, Attach a policy to manipulate all S3 buckets with full permissions, Create Profile, and assign the instance to the profile.

   To mention,
    a supporting S3 bucket will also be created to save Terraform backend state. (see wma_support.sh)
    a key-pair will be created to create the instances with the ssh public key. For security we will save the private key in AWS Sercret manager where it can be retreived to ssh in the servers. (see wma_support.sh)
    Finally, we will use ASW CloudFormer to generate a the cloudFormation template (see mwa-cloudformation.yml)
            
                                                 PART B
   Create an Ansible script (a YAML playbook: wma-playbook.yml) to update the packages and few installs.
   To accomplish this task, we will need to use the Jumbox sever as an Ansible Control Machine, where will install the packages python3, python3-pip,and ansible. (See wma_support.sh, section #Setup Ansible Control Machine)
   
   
