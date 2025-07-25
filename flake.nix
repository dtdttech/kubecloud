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
          src = nixhelm.chartsDerivations.${system}."prometheus-community".prometheus;
          crds = [
            "templates/crds/crd-alertmanagerconfigs.yaml"
            "templates/crds/crd-alertmanagers.yaml"
            "templates/crds/crd-podmonitors.yaml"
            "templates/crds/crd-probes.yaml"
            "templates/crds/crd-prometheusagents.yaml"
            "templates/crds/crd-prometheuses.yaml"
            "templates/crds/crd-prometheusrules.yaml"
            "templates/crds/crd-servicemonitors.yaml"
            "templates/crds/crd-thanosrulers.yaml"
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