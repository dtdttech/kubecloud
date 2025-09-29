# TODO

## Current Goal: Generate CRDs with Nixidy

### Status: Completed

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

### Completed Actions
✅ **Added generators for all missing CRDs**:
- ✅ Traefik (ingressroutes, middlewares, tlsoptions, etc.)
- ✅ Argo CD (applications, applicationsets, appprojects)  
- ✅ MetalLB (bfdprofiles, bgpadvertisements, ipaddresspools, etc.)
- ✅ External DNS (dnsendpoints)
- ✅ Gateway API (gatewayclasses, gateways, httproutes, etc.)

✅ **Updated generation script**:
- Added directories for all new modules
- Updated script to generate all new CRD modules
- Tested individual generators (Gateway API working)

## Remaining Issues
⚠️ **cert-manager CRD generation still needs fixing**:
- Multi-document YAML parsing issue persists
- Generator needs to handle multiple CRDs in one file
- Currently disabled from generation script

3. **Update generation workflow**
   - Modify the `generate` app to run all generators
   - Create directories for new modules if needed
   - Test the complete generation process

#### Next Steps
1. **Fix cert-manager multi-document YAML issue**
   - Split the CRD file into individual documents
   - Or find a way to handle multi-document YAML in the generator
   - Re-enable cert-manager generation

2. **Test all generators**
   - Verify all new generators work correctly
   - Run complete generation script once cert-manager is fixed
   - Integrate generated modules into the environment

## Future Enhancements
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
# Current generation (partially working, cert-manager disabled)
nix run .#generate

# Test individual generators
nix build .#generators.gateway-api
nix build .#generators.cilium
nix build .#generators.traefik

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
- **Completed**: Added generators for all major operators (traefik, argo-cd, metallb, external-dns, gateway-api)
- **Remaining Issue**: cert-manager generation fails due to multi-document YAML parsing
- **Status**: Ready to generate typed options for 45+ CRDs once cert-manager is fixed
- **Testing**: Gateway API and Cilium generators confirmed working