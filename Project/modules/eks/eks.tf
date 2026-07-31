
variable "availability_zones" {
  default = ["af-south-1a", "af-south-1b", "af-south-1c"]
}

variable "vpc_id" {
  default = "vpc-04afeafc288c397af"
}

variable "rt_id" {
  default = "rtb-023fc1846d75af176"
}

# Each environment needs its own non-overlapping subnets, but this trainee is
# only allocated three /24s in the shared VPC. Carve each /24 into /26 blocks
# and hand one block per environment to each AZ:
#   dev  -> x.x.x.0/26
#   int  -> x.x.x.64/26
#   prod -> x.x.x.128/26
locals {
  env_index = {
    dev  = 0
    int  = 1
    prod = 2
  }
  base_subnets = local.subnet_allocation.sherwin_sunker.subnets
  az_cidrs = [
    for cidr in local.base_subnets :
    cidrsubnet(cidr, 2, local.env_index[var.environment])
  ]
}



######################## Trainee Resources ########################

resource "aws_subnet" "az1" {
  vpc_id                  = var.vpc_id
  cidr_block              = local.az_cidrs[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Owner       = "ss sunker"
    Name        = "${var.prefix}-az1-subnet-${var.environment}"
    Environment = var.environment
  }
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_subnet" "az2" {
  vpc_id                  = var.vpc_id
  cidr_block              = local.az_cidrs[1]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = {
    Owner       = "ss sunker"
    Name        = "${var.prefix}-az2-subnet-${var.environment}"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_subnet" "az3" {
  vpc_id                  = var.vpc_id
  cidr_block              = local.az_cidrs[2]
  availability_zone       = var.availability_zones[2]
  map_public_ip_on_launch = true

  tags = {
    Owner       = "ss sunker"
    Name        = "${var.prefix}-az3-subnet-${var.environment}"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_route_table_association" "rt-association-1" {
  subnet_id      = aws_subnet.az1.id
  route_table_id = var.rt_id
}

resource "aws_route_table_association" "rt-association-2" {
  subnet_id      = aws_subnet.az2.id
  route_table_id = var.rt_id
}

resource "aws_route_table_association" "rt-association-3" {
  subnet_id      = aws_subnet.az3.id
  route_table_id = var.rt_id
}

resource "aws_eks_cluster" "eks-cluster" {
  name = "${var.prefix}-eks-${var.environment}"

  access_config {
    authentication_mode = "API"
    #bootstrap_cluster_creator_admin_permissions = true
  }

  role_arn = aws_iam_role.eks-cluster-role.arn
  version  = "1.35"

  vpc_config {
    subnet_ids = [aws_subnet.az1.id, aws_subnet.az2.id, aws_subnet.az3.id]
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
  tags = {
    Owner       = "ss sunker"
    Name        = "${var.prefix}-eks-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_iam_role" "eks-cluster-role" {
  name = "${var.prefix}-eks-cluster-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Owner       = "ss sunker"
    Name        = "${var.prefix}-eks-cluster-role-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster-role.name
}

# authentication_mode = "API" means Kubernetes RBAC access is governed
# entirely by EKS access entries, not IAM policies or aws-auth. Without
# this, the IAM principal that creates/manages the cluster has no way
# to authenticate to the Kubernetes API.
data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "eks-access-entry" {
  cluster_name  = aws_eks_cluster.eks-cluster.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
  tags = {
    Owner       = "ss sunker"
    Name        = "${var.prefix}-eks-access-entry-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.eks-cluster.name
  principal_arn = aws_eks_access_entry.eks-access-entry.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_iam_role" "node-iam-role" {
  name = "${var.prefix}-eks-node-iam-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Owner       = "ss sunker"
    Name        = "${var.prefix}-eks-node-iam-role-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node-iam-role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node-iam-role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node-iam-role.name
}

resource "aws_security_group_rule" "nodeport-ingress-sg" {
  type              = "ingress"
  from_port         = 30007
  to_port           = 30007
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_eks_cluster.eks-cluster.vpc_config[0].cluster_security_group_id
  description       = "Allow inbound access to nginx NodePort service"
}

resource "aws_eks_node_group" "eks-ng" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "${var.prefix}-eks-ng-${var.environment}"
  node_role_arn   = aws_iam_role.node-iam-role.arn
  subnet_ids      = [aws_subnet.az1.id, aws_subnet.az2.id, aws_subnet.az3.id]

  capacity_type  = var.capacity_type
  instance_types = ["t3.micro"]

  scaling_config {
    min_size     = 1
    max_size     = 3
    desired_size = 1
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Owner       = "ss sunker"
    Name        = "${var.prefix}-eks-ng-${var.environment}"
    Environment = var.environment
  }

  # Ensure IAM permissions are created before and deleted after the
  # node group, otherwise EKS cannot properly bootstrap/tear down nodes.
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

variable "prefix" {
  type    = string
  default = "sherwin"
}

variable "environment" {
  type    = string
  default = "dev"
}


 