provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  config_path = "../../../../.kube/config" # your local .kube/config path after you run aws eks update-kubecoonfig --name <cluster-name>
}

provider "helm" {
  kubernetes {
    config_path = "../../../../.kube/config" # your local .kube/config path after you run aws eks update-kubecoonfig --name <cluster-name>
  }
}

# Associate IAM OIDC Provider with EKS
# This enables IAM roles for service accounts on the EKS cluster, allowing Vault to access AWS resources securely

data "terraform_remote_state" "eks" {
  backend = "local"
  config = {
    path = "../../managed_eks/terraform.tfstate"  # Path to the `eks` state file
  }
}

data "aws_eks_cluster" "my_cluster" {
  name = data.terraform_remote_state.eks.outputs.eks_cluster_name
}

data "aws_iam_openid_connect_provider" "eks_oidc" {
  url = data.aws_eks_cluster.my_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "AmazonEKS_EBS_CSI_DriverRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": data.aws_iam_openid_connect_provider.eks_oidc.arn
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(data.aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "attach_ebs_csi_policy" {
  name       = "ebs_csi_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  roles      = [aws_iam_role.ebs_csi_driver_role.name]
}

resource "kubernetes_service_account" "ebs_csi_sa" {
  metadata {
    name      = "ebs-csi-controller-sa"
    namespace = "kube-system"
  }
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                  = data.aws_eks_cluster.my_cluster.name
  addon_name                    = "aws-ebs-csi-driver"
  service_account_role_arn      = aws_iam_role.ebs_csi_driver_role.arn
}

resource "kubernetes_storage_class" "gp2" {
  metadata {
    name        = "gp2"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type = "gp2"

  }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = "vault"
  create_namespace = true
  values = [
    file("${path.module}/values.yaml")
  ]
}
