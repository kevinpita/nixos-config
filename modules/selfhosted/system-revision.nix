{ inputs, ... }:
{
  flake.modules.nixos.node-exporter =
    { config, lib, ... }:
    let
      metricDirectory = "/var/lib/system-revision-metrics";
      revision = config.system.configurationRevision;
      # Applications write into the checkout, so a workstation is often dirty
      # at the main commit. The metric keeps the commit comparable with main.
      commit = if revision == null then "unknown" else lib.removeSuffix "-dirty" revision;
      dirty = if lib.hasSuffix "-dirty" (toString revision) then "yes" else "no";
    in
    {
      # Each host reports the commit that built its system. A checkout with
      # uncommitted changes has only a dirtyRev. Every commit is now a new
      # system generation, also when no package changes.
      system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

      services.prometheus.exporters.node.extraFlags = [
        "--collector.textfile.directory=${metricDirectory}"
      ];

      # Activation runs at boot and on every switch. $systemConfig is the
      # system that activates. /run/current-system still names the old one,
      # and /run/booted-system does not exist during the boot activation.
      system.activationScripts.systemRevisionMetrics.text = ''
        (
          mkdir -p ${metricDirectory}
          reboot_required=0
          if [ -e /run/booted-system ]; then
            for part in kernel initrd kernel-modules; do
              if [ "$(readlink -f "/run/booted-system/$part")" != "$(readlink -f "$systemConfig/$part")" ]; then
                reboot_required=1
              fi
            done
          fi
          {
            printf '# HELP nixos_configuration_revision_info Commit of nixos-config that built the active system.\n'
            printf '# TYPE nixos_configuration_revision_info gauge\n'
            printf 'nixos_configuration_revision_info{revision="%s",dirty="%s"} 1\n' ${
              lib.escapeShellArgs [
                commit
                dirty
              ]
            }
            printf '# HELP nixos_reboot_required Whether the active kernel, initrd, or kernel modules differ from the booted ones.\n'
            printf '# TYPE nixos_reboot_required gauge\n'
            printf 'nixos_reboot_required %s\n' "$reboot_required"
          } > ${metricDirectory}/.revision.prom.tmp
          chmod 0644 ${metricDirectory}/.revision.prom.tmp
          mv -f ${metricDirectory}/.revision.prom.tmp ${metricDirectory}/revision.prom
        )
      '';
    };
}
