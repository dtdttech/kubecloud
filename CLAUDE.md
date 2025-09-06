## Deployment Workflow
- build the project with nix build assume that you need commit everything and push it for deployment
- dont directly apply changes to the cluster e.g. patching config directly, use nixidy build and apply changes via argocd