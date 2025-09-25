# Kubernetes-Managed DNS Zone Setup Guide

## Overview
This guide shows how to set up a Kubernetes-managed DNS zone for `k.vkm.maschinenbau.tu-darmstadt.de` using external-dns.

## Architecture

```
Windows DNS Servers (existing)
    ↓ (delegation)
k.vkm.maschinenbau.tu-darmstadt.de zone
    ↓
Kubernetes Cluster with external-dns
    ↓
CoreDNS (serving k.vkm zone)
```

## Implementation Steps

### 1. Windows DNS Configuration

On your Windows DNS servers, create NS records for the delegation:

```powershell
# Create NS records pointing to your cluster's external IP
Add-DnsServerResourceRecord -ZoneName "vkm.maschinenbau.tu-darmstadt.de" -Name "k" -NS -NameServer "ns1.k.vkm.maschinenbau.tu-darmstadt.de"
Add-DnsServerResourceRecord -ZoneName "vkm.maschinenbau.tu-darmstadt.de" -Name "k" -NS -NameServer "ns2.k.vkm.maschinenbau.tu-darmstadt.de"

# Create A records for the nameservers (pointing to your cluster's external IPs)
Add-DnsServerResourceRecord -ZoneName "vkm.maschinenbau.tu-darmstadt.de" -Name "ns1.k" -A -IPv4Address "YOUR_CLUSTER_EXTERNAL_IP_1"
Add-DnsServerResourceRecord -ZoneName "vkm.maschinenbau.tu-darmstadt.de" -Name "ns2.k" -A -IPv4Address "YOUR_CLUSTER_EXTERNAL_IP_2"
```

### 2. Kubernetes Configuration

The setup includes:

- **external-dns**: Manages DNS records for the k.vkm zone
- **CoreDNS**: Serves the delegated zone
- **Services**: Automatically create DNS records via annotations

### 3. Automatic DNS Record Creation

Services with the following annotation will automatically get DNS records:

```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: "booked.k.vkm.maschinenbau.tu-darmstadt.de"
```

## Updated Services

The following services have been updated to use the k.vkm zone:

- **LibreBooking**: `booked.k.vkm.maschinenbau.tu-darmstadt.de`
- **Grafana**: `grafana.k.vkm.maschinenbau.tu-darmstadt.de`
- **Zammad**: `support.k.vkm.maschinenbau.tu-darmstadt.de`

## Testing

After deployment, test the DNS resolution:

```bash
# Test the delegation
nslookup k.vkm.maschinenbau.tu-darmstadt.de

# Test specific services
nslookup booked.k.vkm.maschinenbau.tu-darmstadt.de
nslookup grafana.k.vkm.maschinenbau.tu-darmstadt.de
```

## Deployment

1. Update your Windows DNS servers with the delegation records
2. Build and deploy the nixidy configuration:
   ```bash
   nix build
   # Push to git repository
   ```
3. Apply the changes via ArgoCD
4. Verify DNS records are created automatically

## Adding New Services

To add new services to the k.vkm zone, simply add the annotation:

```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "your-service.k.vkm.maschinenbau.tu-darmstadt.de"
```

The DNS record will be created automatically when the service is deployed.