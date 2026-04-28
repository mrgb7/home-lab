# Run discovery to generate config
./setup-discovery.sh

# Add the Argo Repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD into the 'argocd' namespace
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f argocd/extra-config.yaml \
  --set configs.credentialTemplates.github-creds.password=$GITHUB_TOKEN \
  --set server.service.type=LoadBalancer \
  --set server.extraArgs={--insecure}
