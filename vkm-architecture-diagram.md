# VKM Environment Kubernetes Architecture Diagram

## Overview
This diagram shows how the VKM environment (vkm.dtdt.tech) is processed through Kubernetes with Longhorn storage, showing the key Kubernetes kinds and their relationships.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            Cloudflare DNS                              │
│                                                                         │
│  vkm.dtdt.tech.    A     192.168.1.100 ────────────┐                   │
│  wiki.vkm.dtdt.tech A     192.168.1.100 ────────────┐│                   │
│  help.vkm.dtdt.tech A     192.168.1.100 ────────────┐││                   │
│  grafana.vkm.dtdt.tech A  192.168.1.100 ────────────┐│││                   │
│  *.vkm.dtdt.tech.   A     192.168.1.100 ────────────┐││││                   │
│  _acme-challenge    TXT   [managed] ────────────────┐│││││                   │
└─────────────────────────────────────────────────────┼┼┼┼┼───────────────────┘
                                                    ││││││
                                                    ││││││
┌─────────────────────────────────────────────────────────────────────────┐
│                          Load Balancer                                 │
│                                                                         │
│                       ┌─────────────────────────────────────────────┐ │
│                       │           Traefik Ingress Controller        │ │
│                       │  (Service: traefik - Type: LoadBalancer)   │ │
│                       │                                             │ │
│                       │  Deployment: traefik (3 replicas)           │ │
│                       │  ┌─────────────────┐                        │ │
│                       │  │  IngressRoute   │                        │ │
│                       │  │                 │                        │ │
│                       │  │ • wiki.vkm.dtdt.tech   │                        │ │
│                       │  │ • help.vkm.dtdt.tech   │                        │ │
│                       │  │ • grafana.vkm.dtdt.tech│                        │ │
│                       │  └─────────────────┘                        │ │
│                       └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                                    │││││
                                                    │││││
┌─────────────────────────────────────────────────────────────────────────┐
│                           Kubernetes API                             │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                        cert-manager                                │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │                  ClusterIssuer: letsencrypt-prod                │ │ │
│ │ │                   Type: ACME Issuer                           │ │ │
│ │ │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │ │ │
│ │ │  │ HTTP01 Solver   │  │ DNS01 Solver    │  │ Certificate      │ │ │ │
│ │ │  │                 │  │ (Cloudflare)    │  │                 │ │ │ │
│ │ │  │ • Ingress       │  │ • Token Secret  │  │ • wiki          │ │ │ │
│ │ │  │ • Port 80       │  │ • Zone: vkm..   │  │ • help          │ │ │ │
│ │ │  └─────────────────┘  └─────────────────┘  │ • grafana       │ │ │ │
│ │ │                                                 • Secret        │ │ │ │
│ │ └─────────────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                                    ││││
                                                    ││││
┌─────────────────────────────────────────────────────────────────────────┐
│                          Application Layer                             │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                         Bookstack                                  │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │  Deployment: bookstack (2 replicas)                            │ │ │
│ │ │  ┌─────────────────────────────────────────────────────────────┐ │ │ │
│ │ │  │                    Service: bookstack                      │ │ │ │
│ │ │  │                     Type: ClusterIP                       │ │ │ │
│ │ │  │                     Port: 80                             │ │ │ │
│ │ │  └─────────────────────────────────────────────────────────────┘ │ │ │
│ │ │ ┌─────────────────────────────────────────────────────────────┐ │ │ │
│ │ │ │                    StatefulSet: bookstack-db               │ │ │ │
│ │ │ │                       Storage: Longhorn PVC               │ │ │ │
│ │ │ │                    Service: bookstack-db                    │ │ │ │
│ │ │ │                     Type: ClusterIP                       │ │ │ │
│ │ │ │                     Port: 5432                           │ │ │ │
│ │ │ └─────────────────────────────────────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────────────────────────────────────┘ │ │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                          Zammad                                    │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │  Deployment: zammad (2 replicas)                               │ │ │
│ │ │  ┌─────────────────────────────────────────────────────────────┐ │ │ │
│ │ │  │                    Service: zammad                         │ │ │ │
│ │ │  │                     Type: ClusterIP                       │ │ │ │
│ │ │  │                     Port: 80                             │ │ │ │
│ │ │  └─────────────────────────────────────────────────────────────┘ │ │ │
│ │ │ ┌─────────────────────────────────────────────────────────────┐ │ │ │
│ │ │ │                    StatefulSet: zammad-db                  │ │ │ │
│ │ │ │                       Storage: Longhorn PVC               │ │ │ │
│ │ │ │                    Service: zammad-db                      │ │ │ │
│ │ │ │                     Type: ClusterIP                       │ │ │ │
│ │ │ │                     Port: 5432                           │ │ │ │
│ │ │ └─────────────────────────────────────────────────────────────┘ │ │ │
│ │ │ ┌─────────────────────────────────────────────────────────────┐ │ │ │
│ │ │ │                   Deployment: zammad-redis                  │ │ │ │
│ │ │ │                       Storage: Longhorn PVC               │ │ │ │
│ │ │ │                    Service: zammad-redis                   │ │ │ │
│ │ │ │                     Type: ClusterIP                       │ │ │ │
│ │ │ │                     Port: 6379                           │ │ │ │
│ │ │ └─────────────────────────────────────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────────────────────────────────────┘ │ │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                         Grafana                                   │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │  Deployment: grafana (1 replica)                               │ │ │
│ │ │  ┌─────────────────────────────────────────────────────────────┐ │ │ │
│ │ │  │                    Service: grafana                       │ │ │ │
│ │ │  │                     Type: ClusterIP                       │ │ │ │
│ │ │  │                     Port: 3000                           │ │ │ │
│ │ │  └─────────────────────────────────────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────────────────────────────────────┘ │ │
└─────────────────────────────────────────────────────────────────────────┘
                                                    ││││
                                                    ││││
┌─────────────────────────────────────────────────────────────────────────┐
│                          Storage Layer                               │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                         Longhorn                                  │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │                   StorageClass: longhorn                       │ │ │
│ │ │                    ReclaimPolicy: Delete                        │ │ │
│ │ │                    AllowVolumeExpansion: true                   │ │ │
│ │ │                    VolumeBindingMode: Immediate                  │ │ │
│ │ └─────────────────────────────────────────────────────────────────┘ │ │
│ │                                                                         │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │              PersistentVolumeClaim Examples:                   │ │ │
│ │ │ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │ │ │
│ │ │ │PVC: bookstack-  │ │PVC: zammad-     │ │PVC: grafana-     │ │ │ │
│ │ │ │    data         │ │    data         │ │    data         │ │ │ │
│ │ │ │StorageClass:    │ │StorageClass:    │ │StorageClass:    │ │ │ │
│ │ │ │longhorn         │ │longhorn         │ │longhorn         │ │ │ │
│ │ │ │Size: 10Gi       │ │Size: 15Gi       │ │Size: 10Gi       │ │ │ │
│ │ └─────────────────┘ └─────────────────┘ └─────────────────┘ │ │ │
│ │ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │ │ │
│ │ │PVC: bookstack-  │ │PVC: zammad-     │ │PVC: zammad-     │ │ │ │
│ │ │    config       │ │    config       │ │    redis         │ │ │ │
│ │ │StorageClass:    │ │StorageClass:    │ │StorageClass:    │ │ │ │
│ │ │longhorn         │ │longhorn         │ │longhorn         │ │ │ │
│ │ │Size: 5Gi        │ │Size: 5Gi        │ │Size: 5Gi        │ │ │ │
│ │ └─────────────────┘ └─────────────────┘ └─────────────────┘ │ │ │
│ │ ┌─────────────────┐                                                  │ │ │
│ │ │PVC: zammad-     │                                                  │ │ │
│ │ │    uploads      │                                                  │ │ │
│ │ │StorageClass:    │                                                  │ │ │
│ │ │longhorn         │                                                  │ │ │
│ │ │Size: 30Gi       │                                                  │ │ │
│ │ └─────────────────┘                                                  │ │ │
│ │ └─────────────────────────────────────────────────────────────────┘ │ │
│ │                                                                         │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │                   Longhorn Nodes                             │ │ │
│ │ │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                 │ │ │
│ │ │ │   Node 1    │ │   Node 2    │ │   Node 3    │                 │ │ │
│ │ │ │  ┌───────┐  │ │  ┌───────┐  │ │  ┌───────┐  │                 │ │ │
│ │ │ │  │ Replica│  │ │  │ Replica│  │ │  │ Replica│  │                 │ │ │
│ │ │ │  │ Manager│  │ │  │ Manager│  │ │  │ Manager│  │                 │ │ │
│ │ │ │  └───────┘  │ │  └───────┘  │ │  └───────┘  │                 │ │ │
│ │ │ │  ┌───────┐  │ │  ┌───────┐  │ │  ┌───────┐  │                 │ │ │
│ │ │ │  │Engine │  │ │  │Engine │  │ │  │Engine │  │                 │ │ │
│ │ │ │  │Manager│  │ │  │Manager│  │ │  │Manager│  │                 │ │ │
│ │ │ │  └───────┘  │ │  └───────┘  │ │  └───────┘  │                 │ │ │
│ │ │ │  ┌───────┐  │ │  ┌───────┐  │ │  ┌───────┐  │                 │ │ │
│ │ │ │  │  CSI   │  │ │  │  CSI   │  │ │  │  CSI   │  │                 │ │ │
│ │ │ │  │ Driver │  │ │  │ Driver │  │ │  │ Driver │  │                 │ │ │
│ │ │ │  └───────┘  │ │  └───────┘  │ │  └───────┘  │                 │ │ │
│ │ │ └─────────────┘ └─────────────┘ └─────────────┘                 │ │ │
│ │ └─────────────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                                    │││
                                                    │││
┌─────────────────────────────────────────────────────────────────────────┐
│                         Monitoring & Secrets                         │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                        Prometheus                                 │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │                  Deployment: prometheus                      │ │ │
│ │ │                     Storage: Longhorn PVC                   │ │ │
│ │ │ ┌─────────────────────────────────────────────────────────────┐ │ │ │
│ │ │ │                   Service: prometheus                      │ │ │ │
│ │ │ │                     Type: ClusterIP                       │ │ │ │
│ │ │ │                     Port: 9090                           │ │ │ │
│ │ │ └─────────────────────────────────────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────────────────────────────────────┘ │ │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                         External Secrets                         │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │                 ClusterSecretStore: onepassword-store         │ │ │
│ │ │                      Server: https://vkm.1password.com        │ │ │
│ │ │ ┌─────────────────────────────────────────────────────────────┐ │ │ │
│ │ │ │               ExternalSecret Examples:                   │ │ │ │
│ │ │ │ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │ │ │ │
│ │ │ │ │ES: bookstack-  │ │ES: zammad-     │ │ES: cloudflare- │ │ │ │ │
│ │ │ │ │    db-creds    │ │    db-creds    │ │    api-token   │ │ │ │ │
│ │ │ │ │StoreRef:      │ │StoreRef:      │ │StoreRef:      │ │ │ │ │
│ │ │ │ │onepassword    │ │onepassword    │ │onepassword    │ │ │ │ │
│ │ │ │ └─────────────────┘ └─────────────────┘ └─────────────────┘ │ │ │ │
│ │ │ └─────────────────────────────────────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                                    │
                                                    │
┌─────────────────────────────────────────────────────────────────────────┐
│                         Backup & External Storage                     │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                         S3 Backup Target                          │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐ │ │
│ │ │                Secret: longhorn-backup-secret                   │ │ │
│ │ │                Target: s3://vkm-backups@us-east-1/              │ │ │
│ │ │                Credentials: AWS Access Key                       │ │ │
│ │ │ └─────────────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

## Processing Flow

### 1. **DNS Resolution Flow**
```
User Request → Cloudflare DNS → Load Balancer → Traefik Ingress → Application Service → Application Pod
```

### 2. **Certificate Management Flow**
```
Let's Encrypt Challenge → cert-manager → Cloudflare API → Certificate Issuance → TLS Secret → Traefik Ingress
```

### 3. **Application Request Flow**
```
1. User requests https://wiki.vkm.dtdt.tech
2. DNS resolves to Load Balancer IP
3. Traefik IngressRoute matches host
4. Routes to bookstack Service (ClusterIP)
5. Service forwards to bookstack Pod
6. Pod accesses database via StatefulSet Service
```

### 4. **Storage Allocation Flow**
```
1. Deployment/StatefulSet requests PVC
2. StorageClass: longhorn processes request
3. Longhorn creates 3-replica volume across nodes
4. PVC bound to PersistentVolume
5. Volume mounted to application pod
```

### 5. **Secret Management Flow**
```
1. ExternalSecret references 1Password
2. ExternalSecrets controller fetches secret
3. Creates Kubernetes Secret
4. Application pod mounts secret
```

## Key Kubernetes Kinds Used

### **Core Resources**
- **Namespace**: Isolates application components
- **Deployment**: Manages pod replicas for stateless apps
- **StatefulSet**: Manages stateful applications with stable identities
- **Service**: Enables communication between pods
- **IngressRoute**: Traefik-specific ingress resource
- **PersistentVolumeClaim**: Requests storage from StorageClass
- **Secret**: Stores sensitive data

### **Storage Resources**
- **StorageClass**: Defines storage provisioner (Longhorn)
- **PersistentVolume**: Physical storage volume
- **Volume**: Mount point for containers

### **Configuration Resources**
- **ConfigMap**: Stores configuration data
- **ClusterIssuer**: Certificate authority configuration
- **Certificate**: SSL certificate resource
- **ExternalSecret**: External secret management
- **ClusterSecretStore**: Secret store configuration

### **Monitoring Resources**
- **ServiceMonitor**: Prometheus service discovery
- **PodMonitor**: Prometheus pod monitoring
- **PrometheusRule**: Alert rules
- **GrafanaDashboard**: Visualization dashboards

### **Network Resources**
- **NetworkPolicy**: Controls pod-to-pod communication
- **ServiceAccount**: Pod identity for API access
- **RoleBinding**: Permission assignment

## Data Flow Through the System

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   User     │───▶│   Cloudflare│───▶│Load Balancer│───▶│   Traefik   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                            │
                                                            ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Grafana   │◀───│  Grafana    │◀───│    Grafana  │◀───│  Bookstack  │
└─────────────┘    │  Service    │    │    Pod      │    │   Service   │
                   └─────────────┘    └─────────────┘    └─────────────┘
                                                            │
                                                            ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Zammad    │◀───│  Zammad     │◀───│    Zammad   │◀───│  Zammad    │
└─────────────┘    │  Service    │    │    Pod      │    │   Service   │
                   └─────────────┘    └─────────────┘    └─────────────┘
                                                            │
                                                            ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Bookstack │◀───│  Bookstack  │◀───│  Bookstack  │◀───│ Bookstack   │
└─────────────┘    │  Service    │    │    Pod      │    │   Service   │
                   └─────────────┘    └─────────────┘    └─────────────┘
```

## Security Isolation

The VKM environment uses multiple security layers:

1. **Network Policies**: Control pod-to-pod communication
2. **RBAC**: Role-based access control for API access
3. **Secrets Management**: External secrets with 1Password integration
4. **TLS Encryption**: End-to-end encryption with Let's Encrypt
5. **Namespace Isolation**: Separate namespaces for different services

This architecture provides a production-ready, scalable, and secure deployment pattern for the VKM environment with comprehensive monitoring and backup capabilities.