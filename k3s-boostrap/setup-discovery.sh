#!/bin/bash

# 1. Setup variables
GITHUB_USER=$(gh api user -q .login)
echo "Detected GitHub User: $GITHUB_USER"

# 2. Create a values file for the ArgoCD Helm chart
# This adds the credential template globally for all user repos
cat <<EOF > argocd/extra-config.yaml
configs:
  credentialTemplates:
    github-creds:
      url: https://github.com/$GITHUB_USER
      username: $GITHUB_USER
      type: git
      password: \$GITHUB_TOKEN
EOF

echo "✅ Created argocd/extra-config.yaml"
echo "------------------------------------------------"
echo "To apply changes, run argocd/install.sh"
