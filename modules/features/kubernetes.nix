{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  helm = pkgs.buildGoModule rec {
    pname = "helm";
    version = "3.20.0";
    src = pkgs.fetchFromGitHub {
      owner = "helm";
      repo = "helm";
      rev = "v${version}";
      hash = "sha256-rJ05qhw8Ebo4EiqZudNe5ETuuzfbJPpy0dZfP7rE2hE=";
    };
    vendorHash = "sha256-dIDSdN7rJ1qkJj2M47OEQDQ+88OYfCpZkmicvNcq/us=";
    doCheck = false;
    subPackages = [ "cmd/helm" ];
    ldflags = [
      "-s"
      "-w"
      "-X helm.sh/helm/v3/internal/version.version=v${version}"
    ];
  };
in
lib.mkIf config.features.kubernetes.enable {
  environment.systemPackages = [
    pkgs.kubectl
    helm
    pkgs.kubectx
    pkgs.k9s
    pkgs.helm-tui
  ];

  home-manager.users.${username} = {
    programs.zsh.shellAliases = {
      k = "kubectl";
      kctx = "kubectx";
      kns = "kubens";
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
}
