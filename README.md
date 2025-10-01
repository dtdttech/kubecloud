# kubecloud

A Kubernetes infrastructure management project using Nix and Nixidy for declarative cluster configuration and GitOps deployment with Argo CD.

## Overview

This project provides a comprehensive Kubernetes stack with:

- **Infrastructure as Code**: All configuration managed through Nix expressions
- **GitOps**: Continuous deployment via Argo CD
- **Type Safety**: Typed resource options generated from CRDs using Nixidy
- **Modular Design**: Self-contained modules for each service/operator

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Development   │    │   Nix Build     │    │   Kubernetes    │
│     Environment │────│     System      │────│    Cluster      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │               ┌───────▼───────┐               │
         │               │   Nixidy     │               │
         │               │   Generator  │               │
         │               └───────────────┘               │
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Argo CD Repository     │
                    │     (GitOps Sync)       │
                    └─────────────────────────┘
```

## Modules

### Infrastructure & Networking
- **[Cilium](modules/cilium/)** - CNI with advanced networking and security policies
- **[CoreDNS](modules/coredns/)** - Cluster DNS service
- **[Traefik](modules/traefik/)** - Ingress controller and reverse proxy
- **[NGINX Ingress](modules/nginx-ingress/)** - Alternative ingress controller
- **[NGINX](modules/nginx/)** - Web server and reverse proxy

### Storage & Data
- **[Ceph CSI](modules/ceph-csi/)** - Ceph storage interface for dynamic provisioning
- **[Storage](modules/storage/)** - Storage class configuration
- **[Samba](modules/samba/)** - SMB/CIFS file sharing
- **[etcd](modules/etcd/)** - Distributed key-value store

### Observability & Monitoring
- **[Prometheus](modules/prometheus/)** - Metrics collection and alerting
- **[Grafana](modules/grafana/)** - Visualization and dashboards
- **[External DNS](modules/external-dns/)** - External DNS management

### Security & Certificate Management
- **[Cert Manager](modules/cert-manager/)** - Automated certificate management
- **[ACME DNS](modules/acme-dns/)** - ACME DNS challenge provider
- **[External Secrets](modules/external-secrets/)** - External secrets management

### Applications & Services
- **[Argo CD](modules/argocd/)** - GitOps continuous delivery
- **[Nextcloud](modules/nextcloud/)** - File synchronization and sharing
- **[Keycloak](modules/keycloak/)** - Identity and access management
- **[Paperless-ngx](modules/paperless/)** - Document management system
- **[Bookstack](modules/bookstack/)** - Wiki and documentation platform
- **[Zammad](modules/zammad/)** - Help desk and customer support
- **[Passbolt](modules/passbolt/)** - Password manager
- **[Seafile](modules/seafile/)** - File synchronization and collaboration
- **[LibreBooking](modules/librebooking/)** - Booking and reservation system
- **[GitHub Runner](modules/github-runner/)** - Self-hosted GitHub Actions runner

## CRD Generation

This project includes comprehensive CRD generation using Nixidy, providing typed resource options for custom resources.

### Generated CRDs

The following operators have CRD generators configured:

| Operator | CRDs Covered | Status |
|----------|-------------|--------|
| **Cilium** | 12 CRDs (Network policies, endpoints, etc.) | ✅ Working |
| **Prometheus** | 9 CRDs (Prometheus, ServiceMonitors, etc.) | ✅ Working |
| **Grafana** | 0 CRDs (pure Helm chart) | ✅ Working |
| **Ceph CSI** | 0 CRDs (CSI driver) | ✅ Working |
| **Cert Manager** | 6 CRDs (Certificates, Issuers, etc.) | ⚠️ Multi-doc YAML issue |
| **Traefik** | 10 CRDs (IngressRoutes, Middlewares, etc.) | ✅ Configured |
| **Argo CD** | 3 CRDs (Applications, AppProjects, etc.) | ✅ Configured |
| **MetalLB** | 8 CRDs (BGP profiles, IP pools, etc.) | ✅ Configured |
| **External DNS** | 1 CRD (DNSEndpoints) | ✅ Configured |
| **Gateway API** | 5 CRDs (Gateways, HTTPRoutes, etc.) | ✅ Working |

**Total CRDs Supported:** 54+ custom resources across 8 operators

### Usage

Generated modules provide typed options for resources:

```nix
applications.my-app.resources = {
  # Typed Gateway API resources
  gateways = {
    my-gateway = {
      spec = {
        gatewayClassName = "traefik";
        listeners = [
          {
            port = 80;
            protocol = "HTTP";
            hostname = "example.com";
          }
        ];
      };
    };
  };

  # Typed Traefik resources
  middlewares = {
    compress = {
      spec = {
        compress = {};
      };
    };
  };
};
```

## Getting Started

### Prerequisites

- Nix package manager
- Kubernetes cluster
- kubectl configured
- Helm (optional, for chart development)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd kubecloud
   ```

2. **Enter development shell**
   ```bash
   nix develop
   ```

3. **Generate CRD modules**
   ```bash
   nix run .#generate
   ```

4. **Build environment**
   ```bash
   nix build .#vkm
   ```

5. **Apply to cluster**
   ```bash
   kubectl apply -f result/
   ```

### Development

#### Adding New Modules

1. Create module directory: `modules/new-service/`
2. Add `default.nix` with module configuration
3. Import in environment configuration
4. Add to generation script if needed

#### Working with CRDs

1. Add generator in `flake.nix`
2. Update generation script
3. Generate with `nix run .#generate`
4. Import generated module in environment

## Environments

### vkm
Main production/staging environment with full stack deployment.

### prod
Production environment configuration.

### dev
Development environment for testing.

## Documentation

- [Storage Configuration](STORAGE.md) - Storage setup and configuration
- [TODO](TODO.md) - Current tasks and roadmap

## Project Status

This is an actively maintained Kubernetes infrastructure project with **20+ modules** covering networking, storage, security, monitoring, and applications. The project uses modern GitOps practices with Nix for reproducible builds and typed configurations.

**Key Features:**
- ✅ Reproducible builds with Nix
- ✅ GitOps deployment via Argo CD  
- ✅ Type-safe resource definitions
- ✅ Comprehensive module ecosystem
- ✅ Automated CRD generation
- ⚠️ cert-manager CRD generation (in progress)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `nix build`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.