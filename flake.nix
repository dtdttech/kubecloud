{
  description = "My ArgoCD configuration with nixidy.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nixidy,
      nixhelm,
      sops-nix,
    }:
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        envs = nixidy.lib.mkEnvs {
          inherit pkgs;
          charts = nixhelm.chartsDerivations.${system} // {

          };
          envs = {
            vkm = {
              modules = [
                ./modules
                ./env/vkm.nix
              ];
            };
            dtdt = {
              modules = [
                ./modules
                ./env/dtdt.nix
              ];
            };
          };
        };
      in
      {
        nixidyEnvs = envs;
        packages = {
          default = envs.vkm.environmentPackage;
          vkm = envs.vkm.environmentPackage;
          dtdt = envs.dtdt.environmentPackage;
          nixidy = nixidy.packages.${system}.default;
          generators = {
            cilium = nixidy.packages.${system}.generators.fromCRD {
              name = "cilium";
              src = pkgs.fetchFromGitHub {
                owner = "cilium";
                repo = "cilium";
                rev = "v1.18.2";
                hash = "sha256-FhXLLppugsdnMo9AiTvch44QtLcNUtj9w5wqE14fo+4=";
              };

              crds = map (v: "pkg/k8s/apis/cilium.io/client/crds/v2/${v}") [
                "ciliumnetworkpolicies.yaml"
                "ciliumclusterwidenetworkpolicies.yaml"
                "ciliumbgpadvertisements.yaml"
                "ciliumbgpclusterconfigs.yaml"
                "ciliumbgpnodeconfigoverrides.yaml"
                "ciliumbgpnodeconfigs.yaml"
                "ciliumbgppeerconfigs.yaml"
                "ciliumcidrgroups.yaml"
                "ciliumclusterwideenvoyconfigs.yaml"
                "ciliumegressgatewaypolicies.yaml"
                "ciliumendpoints.yaml"
                "ciliumenvoyconfigs.yaml"
                "ciliumidentities.yaml"
                "ciliumloadbalancerippools.yaml"
                "ciliumlocalredirectpolicies.yaml"
                "ciliumnodeconfigs.yaml"
                "ciliumnodes.yaml"
              ];
            };
            metallb = nixidy.packages.${system}.generators.fromCRD {
              name = "metallb";
              src = pkgs.fetchFromGitHub {
                owner = "metallb";
                repo = "metallb";
                rev = "v0.15.2";
                hash = "sha256-7jptqytou6Rv4BTcHIzFh++o/O8ojL7Z9b1fHWwQl+U=";
              };
              crds = map (v: "config/crd/bases/${v}") [
                "metallb.io_bfdprofiles.yaml"
                "metallb.io_bgpadvertisements.yaml"
                "metallb.io_bgppeers.yaml"
                "metallb.io_communities.yaml"
                "metallb.io_ipaddresspools.yaml"
                "metallb.io_l2advertisements.yaml"
                "metallb.io_servicebgpstatuses.yaml"
                "metallb.io_servicel2statuses.yaml"
              ];
            };
            traefik = nixidy.packages.${system}.generators.fromCRD {
              name = "traefik";
              src = nixhelm.chartsDerivations.${system}.traefik.traefik;
              crds = map (v: "crds/${v}") [
                "hub.traefik.io_accesscontrolpolicies.yaml"
                "hub.traefik.io_aiservices.yaml"
                "hub.traefik.io_apibundles.yaml"
                "hub.traefik.io_apicatalogitems.yaml"
                "hub.traefik.io_apiplans.yaml"
                "hub.traefik.io_apiportals.yaml"
                "hub.traefik.io_apiratelimits.yaml"
                "hub.traefik.io_apis.yaml"
                "hub.traefik.io_apiversions.yaml"
                "hub.traefik.io_managedapplications.yaml"
                "hub.traefik.io_managedsubscriptions.yaml"
                "traefik.io_ingressroutes.yaml"
                "traefik.io_ingressroutetcps.yaml"
                "traefik.io_ingressrouteudps.yaml"
                "traefik.io_middlewares.yaml"
                "traefik.io_middlewaretcps.yaml"
                "traefik.io_serverstransports.yaml"
                "traefik.io_serverstransporttcps.yaml"
                "traefik.io_tlsoptions.yaml"
                "traefik.io_tlsstores.yaml"
                "traefik.io_traefikservices.yaml"
              ];
            };
            # prometheus = nixidy.packages.${system}.generators.fromCRD {
            #   name = "prometheus";
            #   src = nixhelm.chartsDerivations.${system}."prometheus-community"."kube-prometheus-stack";
            #   crds = [
            #     # "charts/crds/crds/crd-alertmanagerconfigs.yaml" #todo needs fixups
            #     "charts/crds/crds/crd-alertmanagers.yaml"
            #     "charts/crds/crds/crd-podmonitors.yaml"
            #     "charts/crds/crds/crd-probes.yaml"
            #     "charts/crds/crds/crd-prometheusagents.yaml"
            #     "charts/crds/crds/crd-prometheuses.yaml"
            #     "charts/crds/crds/crd-prometheusrules.yaml"
            #     "charts/crds/crds/crd-scrapeconfigs.yaml"
            #     "charts/crds/crds/crd-servicemonitors.yaml"
            #     "charts/crds/crds/crd-thanosrulers.yaml"
            #   ];
            # };
            # grafana = nixidy.packages.${system}.generators.fromCRD {
            #   name = "grafana";
            #   src = nixhelm.chartsDerivations.${system}.grafana.grafana;
            #   crds = [ ];
            # };
            # ceph-csi = nixidy.packages.${system}.generators.fromCRD {
            #   name = "ceph-csi";
            #   src = pkgs.fetchFromGitHub {
            #     owner = "ceph";
            #     repo = "ceph-csi";
            #     rev = "v3.12.0";
            #     hash = "sha256-gCaSAJbnBCwh9kDk1Sb6ByQ2kHhKBg2lMoHdrqW6Jlw=";
            #   };
            #   crds = [ ];
            # };
            # cert-manager = nixidy.packages.${system}.generators.fromCRD {
            #   name = "cert-manager";
            #   src = nixhelm.chartsDerivations.${system}.jetstack.cert-manager;
            #   crds = [
            #     "templates/crds.yaml"
            #   ];
            # };

            # argo-cd = nixidy.packages.${system}.generators.fromCRD {
            #   name = "argo-cd";
            #   src = pkgs.fetchFromGitHub {
            #     owner = "argoproj";
            #     repo = "argo-helm";
            #     rev = "argo-cd-7.7.9";
            #     hash = "sha256-8K5m3H9L7M6N8O9P5Q4R3T2Y1X8W7Z4V6B1C3F2E9D=";
            #   };
            #   crds = [
            #     "charts/argo-cd/crds/application-crd.yaml"
            #     "charts/argo-cd/crds/applicationset-crd.yaml"
            #     "charts/argo-cd/crds/appproject-crd.yaml"
            #   ];
            # };
            # metallb = nixidy.packages.${system}.generators.fromCRD {
            #   name = "metallb";
            #   src = pkgs.fetchFromGitHub {
            #     owner = "metallb";
            #     repo = "metallb";
            #     rev = "v0.14.8";
            #     hash = "sha256-9K5m3H9L7M6N8O9P5Q4R3T2Y1X8W7Z4V6B1C3F2E9D=";
            #   };
            #   crds = [
            #     "config/crd/bases/metallb.io_bfdprofiles.yaml"
            #     "config/crd/bases/metallb.io_bgpadvertisements.yaml"
            #     "config/crd/bases/metallb.io_bgppeers.yaml"
            #     "config/crd/bases/metallb.io_communities.yaml"
            #     "config/crd/bases/metallb.io_ipaddresspools.yaml"
            #     "config/crd/bases/metallb.io_l2advertisements.yaml"
            #     "config/crd/bases/metallb.io_servicebgpstatuses.yaml"
            #     "config/crd/bases/metallb.io_servicel2statuses.yaml"
            #   ];
            # };
            # external-dns = nixidy.packages.${system}.generators.fromCRD {
            #   name = "external-dns";
            #   src = pkgs.fetchFromGitHub {
            #     owner = "kubernetes-sigs";
            #     repo = "external-dns";
            #     rev = "v1.15.0";
            #     hash = "sha256-AK5m3H9L7M6N8O9P5Q4R3T2Y1X8W7Z4V6B1C3F2E9D=";
            #   };
            #   crds = [
            #     "charts/external-dns/crds/crd-dnsendpoints.yaml"
            #   ];
            # };
            # gateway-api = nixidy.packages.${system}.generators.fromCRD {
            #   name = "gateway-api";
            #   src = pkgs.fetchFromGitHub {
            #     owner = "kubernetes-sigs";
            #     repo = "gateway-api";
            #     rev = "v1.1.0";
            #     hash = "sha256-p7eRwjMoDDnZ89sjBxcmYy1J7hT1VG8wQR2VhQ5mi9I=";
            #   };
            #   crds = [
            #     "config/crd/experimental/gateway.networking.k8s.io_gatewayclasses.yaml"
            #     "config/crd/experimental/gateway.networking.k8s.io_gateways.yaml"
            #     "config/crd/experimental/gateway.networking.k8s.io_grpcroutes.yaml"
            #     "config/crd/experimental/gateway.networking.k8s.io_httproutes.yaml"
            #     "config/crd/experimental/gateway.networking.k8s.io_referencegrants.yaml"
            #   ];
            # };
            # github-runner = nixidy.packages.${system}.generators.fromCRD {
            #   name = "github-runner";
            #   src = pkgs.fetchFromGitHub {
            #     owner = "actions";
            #     repo = "actions-runner-controller";
            #     rev = "gha-runner-scale-set-0.12.1";
            #     hash = "sha256-7K5m3H9L7M6N8O9P5Q4R3T2Y1X8W7Z4V6B1C3F2E9D=";
            #   };
            #   crds = [
            #     "charts/gha-runner-scale-set-controller/crds/autoscaling-runner.yaml"
            #     "charts/gha-runner-scale-set-controller/crds/autoscaling-listener.yaml"
            #     "charts/gha-runner-scale-set-controller/crds/runner-set.yaml"
            #     "charts/gha-runner-scale-set-controller/crds/runner-replication-controller.yaml"
            #   ];
            # };
            # nextcloud = nixidy.packages.${system}.generators.fromCRD {
            #   name = "nextcloud";
            #   src = pkgs.fetchFromGitHub {
            #     owner = "nextcloud";
            #     repo = "helm";
            #     rev = "nextcloud-5.5.2";
            #     hash = "sha256-b8qUrRUj9YJP6mEEuDBlzpKViQzyQ3JsQuaq1143kX0=";
            #   } + "/charts/nextcloud";
            #   crds = [];
            # };
          };
        };
        apps = {
          generate = {
            type = "app";
            program =
              (pkgs.writeShellScript "generate-modules" ''
                set -eo pipefail
                mkdir -p modules/cilium modules/grafana modules/nextcloud modules/ceph-csi modules/cert-manager modules/traefik modules/argo-cd modules/metallb modules/external-dns modules/gateway-api modules/github-runner
                cat ${self.packages.${system}.generators.cilium} > modules/cilium/generated.nix
                cat ${self.packages.${system}.generators.metallb} > modules/metallb/generated.nix
                cat ${self.packages.${system}.generators.traefik} > modules/traefik/generated.nix
              '').outPath;
          };
        };
        devShells.default = pkgs.mkShell {
          buildInputs = [ nixidy.packages.${system}.default ];
        };
        formatter = pkgs.nixfmt-tree;
      }
    ));
}
