resource "kubernetes_manifest" "shopflow_root_app" {
  manifest = yamldecode(
    file("${path.root}/../argocd/root-app.yaml")
  )

  depends_on = [
    helm_release.argocd
  ]
}