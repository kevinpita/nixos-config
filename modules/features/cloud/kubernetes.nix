{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.kubernetes.enable {
  environment.systemPackages = [
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.k9s
    pkgs.helm-tui
    pkgs.kubie
  ];

  home-manager.users.${username} = {
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
