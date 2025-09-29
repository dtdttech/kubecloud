# TODO

## Current Goal: Generate CRDs with Nixidy

### Status: In Progress

### Background
The project uses Nixidy to generate Kubernetes manifest modules from CRDs (Custom Resource Definitions). Currently, the cluster has 58 CRDs installed from various operators including:

- **Cert Manager**: certificaterequests, certificates, challenges, clusterissuers, issuers, orders
- **Traefik**: Various gateway API resources, middlewares, ingressroutes, etc.
- **Cilium**: Network policies, endpoints, identities, etc.
- **Argo CD**: Applications, application sets, app projects
- **MetalLB**: BGP profiles, IP address pools, etc.
- **External DNS**: DNS endpoints
- **K3S**: Addons, etcd snapshot files, helm charts

### Current State
✅ **Completed**:
- Research existing CRDs in the codebase
- Identify available CRDs from installed operators
- Set up Nixidy CRD generation configuration
- Found 58 CRDs in the current cluster

⚠️ **Issues Found**:
- Cert Manager CRD generation fails due to multi-document YAML parsing issues
- The `templates/crds.yaml` file contains multiple YAML documents which breaks the crd2jsonschema tool

### Next Steps

#### Immediate Actions
1. **Fix cert-manager CRD generation**
   - Split the multi-document YAML into individual files
   - Update the flake.nix configuration to handle multiple CRD files
   - Test the generation process

2. **Add missing CRD generators**
   - Add generators for other operators (Traefik, Argo CD, MetalLB, etc.)
   - Update the generation script to include all new generators
   - Ensure all 58 CRDs are covered

3. **Update generation workflow**
   - Modify the `generate` app to run all generators
   - Create directories for new modules if needed
   - Test the complete generation process

#### Future Enhancements
1. **Automate CRD updates**
   - Set up a workflow to automatically detect new CRDs in the cluster
   - Generate Nixidy modules for newly installed operators
   - Keep the generated modules in sync with the cluster

2. **Validation and Testing**
   - Add validation that all CRDs are properly converted to Nix schemas
   - Test that the generated modules work correctly in the environment
   - Ensure backward compatibility when CRDs are updated

### Commands to Run
```bash
# Current generation (partially working)
nix run .#generate

# Check what CRDs are available
kubectl get crd --no-headers | sort

# Check specific CRDs
kubectl get crd certificaterequests.cert-manager.io -o yaml
```

### Configuration Files
- `flake.nix`: Contains Nixidy generators configuration
- `modules/*/generated.nix`: Generated CRD modules
- `apps.generate`: Generation script in flake.nix

### Notes
- The generation process works for most operators but fails on cert-manager due to YAML parsing
- The project already has generators for cilium, prometheus, grafana, ceph-csi, and cert-manager
- Need to add generators for traefik, argo-cd, metallb, external-dns, and other operators