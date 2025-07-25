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
  };


  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nixidy,
    nixhelm,
  }: (flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
    };
    envs = nixidy.lib.mkEnvs {
      inherit pkgs;
      charts = nixhelm.chartsDerivations.${system};
      envs = {
        prod = {
          specialArgs = {
            
          };
          modules = [
            ./modules
            ./env/prod.nix
          ];
        };
      };
    };
  in {
    nixidyEnvs = envs;
    packages = {
      default = envs.prod.environmentPackage;
      nixidy = nixidy.packages.${system}.default;
      generators = {
        cilium = nixidy.packages.${system}.generators.fromCRD {
          name = "cilium";
          src = pkgs.fetchFromGitHub {
            owner = "cilium";
            repo = "cilium";
            rev = "v1.17.5";
            hash = "sha256-frpu1kJICbZFwmH/KQ2pZHcS2M+XvLvxZpzVxok2eM8=";
          };
          crds = [
            "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnetworkpolicies.yaml"
            "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumclusterwidenetworkpolicies.yaml"
          ];
        };
        traefik = nixidy.packages.${system}.generators.fromCRD {
          name = "traefik";
          src = nixhelm.chartsDerivations.${system}.traefik.traefik;
          crds = [
            "crds/traefik.io_ingressroutes.yaml"
            "crds/traefik.io_ingressroutetcps.yaml"
            "crds/traefik.io_ingressrouteudps.yaml"
            "crds/traefik.io_traefikservices.yaml"
          ];
        };
        prometheus = nixidy.packages.${system}.generators.fromCRD {
          name = "prometheus";
          src = nixhelm.chartsDerivations.${system}."prometheus-community"."kube-prometheus-stack";
          crds = [
            # "charts/crds/crds/crd-alertmanagerconfigs.yaml" #todo needs fixups
            "charts/crds/crds/crd-alertmanagers.yaml"
            "charts/crds/crds/crd-podmonitors.yaml"
            "charts/crds/crds/crd-probes.yaml"
            "charts/crds/crds/crd-prometheusagents.yaml"
            "charts/crds/crds/crd-prometheuses.yaml"
            "charts/crds/crds/crd-prometheusrules.yaml"
            "charts/crds/crds/crd-scrapeconfigs.yaml"
            "charts/crds/crds/crd-servicemonitors.yaml"
            "charts/crds/crds/crd-thanosrulers.yaml"
          ];
        };
      };
    };
    apps = {
      generate = {
        type = "app";
        program =
          (pkgs.writeShellScript "generate-modules" ''
            set -eo pipefail
            mkdir -p modules/cilium modules/traefik
            cat ${self.packages.${system}.generators.cilium} > modules/cilium/generated.nix
            cat ${self.packages.${system}.generators.traefik} > modules/traefik/generated.nix
            cat ${self.packages.${system}.generators.prometheus} > modules/prometheus/generated.nix
          '')
          .outPath;
      };
    };

    # Useful development shell with nixidy in path.
    # Run `nix develop` to enter.
    devShells.default = pkgs.mkShell {
      buildInputs = [nixidy.packages.${system}.default];
    };
  }));
}