# Stakater Reloader - Reinicia pods automáticamente cuando cambian ConfigMaps/Secrets
resource "helm_release" "reloader" {
  name       = "reloader"
  repository = "https://stakater.github.io/stakater-charts"
  chart      = "reloader"
  version    = "1.0.119"
  namespace  = "kube-system"

  set {
    name  = "reloader.watchGlobally"
    value = "true"
  }

  set {
    name  = "reloader.ignoreSecrets"
    value = "false"
  }

  set {
    name  = "reloader.ignoreConfigMaps"
    value = "false"
  }

  depends_on = [
    module.eks,
    helm_release.aws_load_balancer_controller
  ]
}
