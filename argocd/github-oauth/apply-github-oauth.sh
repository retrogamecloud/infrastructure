#!/bin/bash
set -e

echo "🔐 Configurando GitHub OAuth para ArgoCD"
echo "=========================================="
echo ""
echo "⚠️  NOTA: Este script es para aplicación manual inicial."
echo "    Para gestión persistente con GitOps, usa:"
echo "    kubectl apply -f ../../../kubernetes/argocd-config/argocd-config-app.yaml"
echo ""

# Verificar que estamos en el namespace correcto
echo "📋 Verificando namespace argocd..."
if ! kubectl get namespace argocd &>/dev/null; then
  echo "❌ Namespace argocd no existe"
  exit 1
fi

echo "✅ Namespace argocd encontrado"
echo ""

# Opción: usar Kustomize o kubectl directo
read -p "¿Usar Kustomize desde kubernetes/argocd-config? (y/n): " USE_KUSTOMIZE

if [[ "$USE_KUSTOMIZE" == "y" ]]; then
  echo "📦 Aplicando configuración con Kustomize..."
  kubectl apply -k ../../../kubernetes/argocd-config/overlays/production
else
  # Aplicar Secret
  echo "🔑 Aplicando Secret con GitHub OAuth credentials..."
  kubectl apply -f argocd-secret-github.yaml
  
  echo "✅ Secret aplicado"
  echo ""
  
  # Hacer patch del ConfigMap (merge con el existente)
  echo "⚙️  Haciendo patch del ConfigMap argocd-cm..."
  kubectl patch configmap argocd-cm -n argocd --type merge -p '
{
  "data": {
    "url": "https://retrogamehub.games/argocd",
    "dex.config": "connectors:\n- type: github\n  id: github\n  name: GitHub\n  config:\n    clientID: Ov23lil4DINdiuLj2XnS\n    clientSecret: $dex.github.clientSecret\n    orgs:\n    - name: retrogamecloud\n    loadAllGroups: false\n    teamNameField: slug\n    useLoginAsID: false\n",
    "policy.default": "role:readonly",
    "policy.csv": "g, retrogamecloud:*, role:admin\n"
  }
}'
fi

echo "✅ ConfigMap actualizado"
echo ""

# Reiniciar deployments
echo "🔄 Reiniciando ArgoCD server y dex-server..."
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout restart deployment/argocd-dex-server -n argocd

echo "✅ Deployments reiniciados"
echo ""

echo "⏳ Esperando a que los pods estén listos..."
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=120s deployment/argocd-dex-server -n argocd

echo ""
echo "✅ ¡Configuración completada!"
echo ""
echo "🌐 Ahora puedes acceder a: https://retrogamehub.games/argocd"
echo "🔐 Haz click en 'LOG IN VIA GITHUB' para autenticarte"
echo ""
echo "⚠️  IMPORTANTE: Asegúrate de haber añadido el callback URL en GitHub OAuth App:"
echo "   https://retrogamehub.games/argocd/api/dex/callback"
echo ""
echo "💡 Para gestión GitOps persistente, aplica la ArgoCD Application:"
echo "   kubectl apply -f ../../../kubernetes/argocd-config/argocd-config-app.yaml"
echo ""
