{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "prometheus-podman-exporter";
  version = "1.21.2";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "prometheus-podman-exporter";
    tag = "v${finalAttrs.version}";
    hash = "sha256-7AU/LWRClwuPEEalhanglMlpXirzFELhdX+6lbu/6zA=";
  };

  vendorHash = null;
  subPackages = [ "." ];

  env.CGO_ENABLED = 0;
  tags = [
    "remote"
    "containers_image_openpgp"
  ];
  ldflags = [
    "-s"
    "-w"
    "-X github.com/containers/prometheus-podman-exporter/cmd.buildVersion=${finalAttrs.version}"
    "-X github.com/containers/prometheus-podman-exporter/cmd.buildRevision=${finalAttrs.src.tag}"
  ];

  # Upstream tests require a running Podman engine.
  doCheck = false;

  meta = {
    description = "Prometheus exporter for Podman using its socket API";
    homepage = "https://github.com/containers/prometheus-podman-exporter";
    changelog = "https://github.com/containers/prometheus-podman-exporter/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "prometheus-podman-exporter";
    platforms = lib.platforms.linux;
  };
})
