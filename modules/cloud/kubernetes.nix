{
  flake.modules.nixos.kubernetes =
    {
      config,
      lib,
      pkgs,
      inputs,
      username,
      ...
    }:
    let
      hulkKubeconfigFile =
        if inputs ? nixos-secrets then "${inputs.nixos-secrets}/secrets/hulk-kubeconfig.enc" else null;
      hasHulkKubeconfig =
        config.hostSecrets.enable && hulkKubeconfigFile != null && builtins.pathExists hulkKubeconfigFile;
    in
    {
      environment.systemPackages = [
        pkgs.kubectl
        pkgs.kubernetes-helm
        pkgs.k9s
        pkgs.helm-tui
        pkgs.ku
        pkgs.kubie
        pkgs.argocd
      ];

      sops.secrets = lib.mkIf hasHulkKubeconfig {
        "hulk-kubeconfig" = {
          sopsFile = hulkKubeconfigFile;
          format = "json";
          key = "data";
          owner = username;
          path = "/home/${username}/.kube/config_hulk";
          mode = "0600";
        };
      };

      systemd.tmpfiles.rules = lib.mkIf hasHulkKubeconfig [
        "d /home/${username}/.kube 0700 ${username} users -"
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
