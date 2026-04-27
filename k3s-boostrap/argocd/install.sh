# Add the Argo Repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD into the 'argocd' namespace
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=ClusterIP \
  --set server.extraArgs={--insecure}
