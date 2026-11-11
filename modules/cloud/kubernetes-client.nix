{
  flake.modules.nixos.kubernetes-client =
    {
      inputs,
      lib,
      pkgs,
      username,
      ciMode,
      ...
    }:
    let
      helm3 = pkgs.stdenvNoCC.mkDerivation {
        pname = "kubernetes-helm";
        version = "3.22.0";
        src = pkgs.fetchurl {
          url = "https://get.helm.sh/helm-v3.22.0-linux-amd64.tar.gz";
          hash = "sha256-Hkq0nkKWJs9saVjZFCSLeMlzCAPCdRuHYn4XHcgA57s=";
        };
        installPhase = ''
          install -Dm755 helm $out/bin/helm
        '';
        meta.mainProgram = "helm";
      };
      helm = pkgs.wrapHelm helm3 {
        plugins = [ pkgs.kubernetes-helmPlugins.helm-diff ];
      };
      fluxcd = pkgs.stdenvNoCC.mkDerivation {
        pname = "fluxcd";
        version = "2.10.0";
        src = pkgs.fetchurl {
          url = "https://github.com/fluxcd/flux2/releases/download/v2.10.0/flux_2.10.0_linux_amd64.tar.gz";
          hash = "sha256-II3XASwE/t7tWy0LbmPfOxWxw0o4FSeBFoXAmLyfhlk=";
        };
        sourceRoot = ".";
        nativeBuildInputs = [ pkgs.installShellFiles ];
        installPhase = ''
          runHook preInstall
          install -Dm755 flux $out/bin/flux
          installShellCompletion --cmd flux \
            --bash <($out/bin/flux completion bash) \
            --fish <($out/bin/flux completion fish) \
            --zsh <($out/bin/flux completion zsh)
          runHook postInstall
        '';
        meta = pkgs.fluxcd.meta // {
          platforms = [ "x86_64-linux" ];
          changelog = "https://github.com/fluxcd/flux2/releases/tag/v2.10.0";
        };
      };
      secretsPath = "${inputs.nixos-secrets}/secrets";
      kubeFiles = lib.filterAttrs (
        name: type: type == "regular" && builtins.match "kube-.+\\.yaml" name != null
      ) (builtins.readDir secretsPath);
    in
    {
      sops.secrets = lib.optionalAttrs (!ciMode) (
        lib.mapAttrs' (
          name: _:
          lib.nameValuePair (lib.removeSuffix ".yaml" name) {
            sopsFile = "${secretsPath}/${name}";
            format = "yaml";
            key = "";
            owner = username;
            mode = "0600";
            path = "/home/${username}/.kube/${name}";
          }
        ) kubeFiles
      );

      environment.systemPackages = [
        fluxcd
        pkgs.helm-tui
        pkgs.k9s
        pkgs.ku
        pkgs.kubectl
        helm
        pkgs.kubie
        pkgs.terraform
      ];

      home-manager.users.${username} = {
        home.file.".kube/kubie.yaml".text = ''
          configs:
            include:
              - "~/.kube/config"
              - "~/.kube/config_*"
              - "~/.kube/*.yml"
              - "~/.kube/*.yaml"
              - "~/.kube/configs/*.yml"
              - "~/.kube/configs/*.yaml"
              - "~/.kube/kubie/*.yml"
              - "~/.kube/kubie/*.yaml"
            exclude:
              - "~/.kube/kubie.yaml"
        '';

        programs.zsh = {
          shellAliases = {
            k = "kubectl";
            kctx = "kubie ctx";
            kns = "kubie ns";
            kgp = "kubectl get pods";
            kgs = "kubectl get svc";
            kgn = "kubectl get nodes";
            kgd = "kubectl get deployments";
            kgi = "kubectl get ingress";
            kga = "kubectl get all";
            kaf = "kubectl apply -f";
            kdf = "kubectl delete -f";
            kdp = "kubectl describe pod";
            kds = "kubectl describe svc";
            kdd = "kubectl describe deployment";
            kl = "kubectl logs";
            klf = "kubectl logs -f";
            kei = "kubectl exec -it";
            hls = "helm ls";
            hra = "helm ls -a";
          };
        };
      };
    };
}
