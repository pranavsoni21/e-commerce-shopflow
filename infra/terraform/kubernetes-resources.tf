resource "kubernetes_namespace" "shopflow" {
  metadata {
    name = "shopflow"
  }
  depends_on = [module.eks.cluster_endpoint]
}

resource "kubernetes_secret" "shopflow_db" {
  metadata {
    name      = "shopflow-db"
    namespace = kubernetes_namespace.shopflow.metadata[0].name
  }

  type = "Opaque"

  data = {
    USER_DATABASE_URL = "postgresql://${var.db_username}:${var.db_password}@${module.rds.db_host}:5432/userdb"

    PRODUCT_DATABASE_URL = "postgresql://${var.db_username}:${var.db_password}@${module.rds.db_host}:5432/productdb"

    ORDER_DATABASE_URL = "postgresql://${var.db_username}:${var.db_password}@${module.rds.db_host}:5432/orderdb"

    JWT_SECRET = var.jwt_secret
  }

  depends_on = [module.rds.db_host]
}

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
       "eks.amazonaws.com/role-arn" = module.iam.load_balancer_controller_role_arn
    }
  }
}
