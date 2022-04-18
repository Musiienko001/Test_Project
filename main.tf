
provider "aws" {
  access_key = "AKIAYT6LKGJKJRETATXP"
  secret_key = "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"
  region = "eu-central-1"
}


# Added Docker repository in ECR--------------------------------------------------------------------
resource "aws_ecr_repository" "foo" {
name                 = "frontend"
image_tag_mutability = "MUTABLE"

image_scanning_configuration {
scan_on_push = true
}
}

resource "aws_ecr_repository" "foo2" {
  name                 = "backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Added VPS---------------------------------------------------------------------------------------
resource "aws_vpc" "main" {
cidr_block = "10.0.0.0/16"
}
# Added Public subnet------------------------------------------------------------------------------

resource "aws_subnet" "aws_subnet_public1" {
vpc_id     = aws_vpc.main.id
cidr_block = "10.0.1.0/24"
availability_zone       = "eu-central-1a"
tags = {
Name = "kubernetes.io/cluster/eks_cluster"
}
}

resource "aws_subnet" "aws_subnet_public2" {
vpc_id     = aws_vpc.main.id
cidr_block = "10.0.2.0/24"
availability_zone       = "eu-central-1b"
tags = {
Name = "kubernetes.io/cluster/eks_cluster"
}
}

# Added Private subnet-----------------------------------------------------------------------------
resource "aws_subnet" "aws_subnet_private1" {
vpc_id     = aws_vpc.main.id
cidr_block = "10.0.11.0/24"
  map_public_ip_on_launch = true
availability_zone       = "eu-central-1a"
tags = {
Name = "aws_subnet_private1"
}
 # subnet.MapPublicIpOnLaunch = True
}

#resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr" {
 # vpc_id     = aws_vpc.main.id
  #cidr_block = "172.2.0.0/16"
#}

#resource "aws_subnet" "in_secondary_cidr" {
 # vpc_id     = aws_vpc_ipv4_cidr_block_association.secondary_cidr.vpc_id
  #cidr_block = "172.2.0.0/24"
#}




resource "aws_subnet" "aws_subnet_private2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.12.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1b"
  tags = {
    Name = "aws_subnet_private2"
  }
}
# Add Internet gatewey
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "main"
  }
}



# Added Route Table Public------------------------------------------------------------------------------------

resource "aws_route_table" "aws_route_table" {
vpc_id = "${aws_vpc.main.id}"
route {
cidr_block = "0.0.0.0/0"
gateway_id = "${aws_internet_gateway.gw.id}"
}
tags  = {
Name          = "aws_internet_gateway-default"
Environment   = "dev"
Orchestration = "k8s"
}
}

# associacion public subnet---------------------------------------------------------------------------------------
resource "aws_route_table_association" "aws_route_table_association_public1" {
subnet_id = "${aws_subnet.aws_subnet_public1.id}"
route_table_id = "${aws_route_table.aws_route_table.id}"
}

resource "aws_route_table_association" "aws_route_table_association_public2" {
subnet_id = "${aws_subnet.aws_subnet_public2.id}"
route_table_id = "${aws_route_table.aws_route_table.id}"
}


# associacion private subnet-----------------------------------------------------------------------------------
resource "aws_route_table_association" "aws_route_table_association_private1" {
subnet_id       = "${aws_subnet.aws_subnet_private1.id}"
route_table_id  = "${aws_route_table.aws_route_table.id}"
}



resource "aws_route_table_association" "aws_route_table_association_private2" {
  subnet_id       = "${aws_subnet.aws_subnet_private2.id}"
  route_table_id  = "${aws_route_table.aws_route_table.id}"
}

# Added Elastic IP--------------------------------------------------------------------------------------------
#resource "aws_eip" "aws_eip" {
#vpc         = true
#depends_on = [aws_internet_gateway.gw]
#}

# Create public NAT--------------------------------------------------------------------------------------------------
#resource "aws_nat_gateway" "public1" {
#allocation_id = aws_eip.aws_eip.id
#subnet_id    = aws_subnet.aws_subnet_public1.id

#tags = {
#Name = "gw NAT"
#}
# To ensure proper ordering, it is recommended to add an explicit dependency
# on the Internet Gateway for the VPC.
#depends_on = [aws_internet_gateway.gw]
#}

#   allocation_id = aws_eip.aws_eip.id
#    subnet_id     = aws_subnet.aws_subnet_public2.id

#  tags = {
#     Name = "gw NAT2"
#    }

# To ensure proper ordering, it is recommended to add an explicit dependency
# on the Internet Gateway for the VPC.
# depends_on = [aws_internet_gateway.gw]
#}

# Create private NAT---------------------------------------------------------------------------------------------

resource "aws_nat_gateway" "private" {
connectivity_type = "private"
subnet_id         = aws_subnet.aws_subnet_private1.id
}

resource "aws_nat_gateway" "private2" {
  connectivity_type = "private"
  subnet_id         = aws_subnet.aws_subnet_private2.id

}


# Added Security group--------------------------------------------------------------------------------------------

resource "aws_security_group" "allow_tls" {
name        = "allow_tls"
description = "Allow TLS inbound traffic"
vpc_id      = "${aws_vpc.main.id}"

ingress {
description      = "TLS from VPC"
from_port        = 80
to_port          = 80
protocol         = "tcp"
cidr_blocks      = ["0.0.0.0/0"]
}

egress {
from_port        = 0
to_port          = 0
protocol         = "-1"
cidr_blocks      = ["0.0.0.0/0"]
}

tags = {
Name = "allow_tls"
}
}

# Created EKS Cluster--------------------------------------------------------------------------------------------

resource "aws_iam_role" "eks_cluster" {
name = "eks-cluster"

assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_cluster" "aws_eks" {
name     = "eks_cluster"
role_arn = aws_iam_role.eks_cluster.arn

vpc_config {
subnet_ids = [aws_subnet.aws_subnet_private1.id, aws_subnet.aws_subnet_private2.id]
}

tags = {
Name = "EKS_tuto"
}
}




# EKS Node Groups
resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.aws_eks.name
  node_group_name = "node"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [aws_subnet.aws_subnet_private1.id, aws_subnet.aws_subnet_private2.id]

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  ami_type       = "AL2_x86_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM
  capacity_type  = "ON_DEMAND"  # ON_DEMAND, SPOT
  disk_size      = 20
  instance_types = ["t2.micro"] #medium

  #tags = merge(

 # )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}


# EKS Node IAM Role
resource "aws_iam_role" "node" {
  name = "this-Worker-Role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}


# EKS Node Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "this-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                           = "this-node-sg"
    "kubernetes.io/cluster/this-cluster" = "owned"


  }
}















# Added EKS NODES--------------------------------------------------------------------------------------

 # resource "aws_iam_role" "eks_nodes" {
  #name = "eks-node-group-tuto"

 # assume_role_policy = <<POLICY
#{
 #"Version": "2012-10-17",
#"Statement": [
 #{
  #"Effect": "Allow",
 #"Principal": {
 # "Service": "ec2.amazonaws.com"
# },
#"Action": "sts:AssumeRole"
#}
#]
#}
#POLICY
#}

#resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
 #policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#role       = aws_iam_role.eks_nodes.name
#}

#resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
# policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#role       = aws_iam_role.eks_nodes.name
#}

#resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
# policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
# role       = aws_iam_role.eks_nodes.name
#}

#resource "aws_eks_node_group" "node" {
 #cluster_name    = aws_eks_cluster.aws_eks.name
#node_group_name = "node_tuto"
#node_role_arn   = aws_iam_role.eks_nodes.arn
#subnet_ids      = [aws_subnet.aws_subnet_public1.id, aws_subnet.aws_subnet_public2.id]

#scaling_config {
 #desired_size = 1
 #max_size     = 1
#min_size     = 1
#}

# Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
# Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
#depends_on = [
 #aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
 #aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
 #aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
#]
# }

# Create Load Balancer for application------------------------------------------------------------------------------

#resource "aws_lb" "test" {
#name               = "test-lb-tf"
#internal           = false
#load_balancer_type = "application"
#security_groups    = [aws_security_group.allow_tls.id]
#subnets            = [aws_subnet.aws_subnet_private1.id, aws_subnet.aws_subnet_private2.id]




#tags = {
#Environment = "production"
#}
#}
