provider "helm" {
  kubernetes {
    config_path = "../../.kube/kubeconfig"
  }
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  chart      = "jenkins"
  repository = "https://charts.jenkins.io"
  namespace  = "jenkins"
  create_namespace = true
  values = [
    file("${path.module}/values.yaml")
  ]
}

resource "kubernetes_storage_class" "jenkins_storage" {
  metadata {
    name = "jenkins-storage"  # Custom name for the storage class
  }

  provisioner          = "ebs.csi.aws.com"  # AWS EBS CSI provisioner
  volume_binding_mode  = "WaitForFirstConsumer"
  reclaim_policy       = "Retain"

  parameters = {
    type       = "gp2"   # EBS volume type; adjust as needed
    encrypted  = "true"  # Optional: set true to encrypt EBS volumes
  }
}

resource "kubernetes_service_account" "jenkins_sa" {
  metadata {
    name      = "jenkins-sa"
    namespace = "jenkins"
  }
}

resource "kubernetes_cluster_role_binding" "jenkins_role_binding" {
  metadata {
    name = "jenkins-role-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins_sa.metadata[0].name
    namespace = kubernetes_service_account.jenkins_sa.metadata[0].namespace
  }
}
