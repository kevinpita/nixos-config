{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}:
let
  hasSecrets = inputs ? nixos-secrets;
in
lib.mkIf config.features.kubernetes.enable {
  environment.systemPackages = [
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.k9s
    pkgs.helm-tui
    pkgs.kubie
  ];

  sops.secrets = lib.mkIf hasSecrets {
    "hulk-kubeconfig" = {
      sopsFile = "${inputs.nixos-secrets}/secrets/hulk-kubeconfig.enc";
      format = "json";
      key = "data";
      owner = username;
      path = "/home/${username}/.kube/config_hulk";
      mode = "0600";
    };
  };

  systemd.tmpfiles.rules = lib.mkIf hasSecrets [
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
}
