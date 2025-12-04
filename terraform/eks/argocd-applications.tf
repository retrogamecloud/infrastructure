# ============================================================================
# ArgoCD Applications - Despliegue automático de aplicaciones
# ============================================================================

# Application de configuración de ArgoCD
resource "kubectl_manifest" "argocd_config_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: argocd-config
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      
      source:
        repoURL: https://github.com/retrogamecloud/infrastructure
        targetRevision: main
        path: argocd/overlays/production
      
      destination:
        server: https://kubernetes.default.svc
        namespace: argocd
      
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=false
          - ServerSideApply=true
  YAML

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.argocd_repo_infrastructure
  ]
}

# Application de las apps de retrogame
resource "kubectl_manifest" "retrogame_apps_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: retrogame-apps
      namespace: argocd
      annotations:
        notifications.argoproj.io/subscribe.on-deployed.slack: argocdretrogame
        notifications.argoproj.io/subscribe.on-sync-failed.slack: argocdretrogame
        notifications.argoproj.io/subscribe.on-health-degraded.slack: argocdretrogame
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      
      source:
        repoURL: https://github.com/retrogamecloud/kubernetes
        targetRevision: main
        path: argocd/overlays/production
      
      destination:
        server: https://kubernetes.default.svc
        namespace: retrogame
      
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
          allowEmpty: false
        syncOptions:
          - CreateNamespace=false
          - PrunePropagationPolicy=foreground
          - PruneLast=true
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
      
      revisionHistoryLimit: 10
  YAML

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.argocd_repo_kubernetes,
    kubernetes_namespace.retrogame
  ]
}

# Application de platform de retrogame
resource "kubectl_manifest" "retrogame_platform_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: retrogame-platform
      namespace: argocd
      annotations:
        notifications.argoproj.io/subscribe.on-deployed.slack: argocdretrogame
        notifications.argoproj.io/subscribe.on-sync-failed.slack: argocdretrogame
        notifications.argoproj.io/subscribe.on-health-degraded.slack: argocdretrogame
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      
      source:
        repoURL: https://github.com/retrogamecloud/kubernetes
        targetRevision: main
        path: platform/overlays/production
      
      destination:
        server: https://kubernetes.default.svc
        namespace: retrogame
      
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
          allowEmpty: false
        syncOptions:
          - CreateNamespace=false
          - PrunePropagationPolicy=foreground
          - PruneLast=true
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
      
      revisionHistoryLimit: 10
  YAML

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.argocd_repo_kubernetes,
    kubernetes_namespace.retrogame
  ]
}
