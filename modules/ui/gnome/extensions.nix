{
  flake.modules.nixos.gnome =
    {
      pkgs,
      username,
      ...
    }:
    let
      codexUsageExtension = pkgs.gnomeExtensions.buildShellExtension {
        uuid = "codex-usage@kevinpita.dev";
        name = "Codex Usage";
        pname = "codex-usage";
        description = "Display OpenAI Codex usage from local session data in the top panel.";
        link = "https://extensions.gnome.org/extension/9703/codex-usage/";
        version = 1;
        sha256 = "sha256-IriZg+hs0aghCz7WIc+jgnfKsEQYvKBQm3CWwBzQKrc=";
        metadata = "ewogICJfZ2VuZXJhdGVkIjogIkdlbmVyYXRlZCBieSBTd2VldFRvb3RoLCBkbyBub3QgZWRpdCIsCiAgImRlc2NyaXB0aW9uIjogIkRpc3BsYXkgT3BlbkFJIENvZGV4IHVzYWdlIGZyb20gbG9jYWwgc2Vzc2lvbiBkYXRhIGluIHRoZSB0b3AgcGFuZWwuIEZvcmtlZCBmcm9tIGNsYXVkZS11c2FnZS1leHRlbnNpb24gYnkgSGFsZXRyYW4uIFRoaXMgZXh0ZW5zaW9uIGlzIG5vdCBhZmZpbGlhdGVkLCBmdW5kZWQsIG9yIGluIGFueSB3YXkgYXNzb2NpYXRlZCB3aXRoIE9wZW5BSS4iLAogICJkb25hdGlvbnMiOiB7CiAgICAiZ2l0aHViIjogImtldmlucGl0YSIKICB9LAogICJuYW1lIjogIkNvZGV4IFVzYWdlIiwKICAic2V0dGluZ3Mtc2NoZW1hIjogIm9yZy5nbm9tZS5zaGVsbC5leHRlbnNpb25zLmNvZGV4LXVzYWdlIiwKICAic2hlbGwtdmVyc2lvbiI6IFsKICAgICI0NiIsCiAgICAiNDciLAogICAgIjQ4IiwKICAgICI0OSIsCiAgICAiNTAiCiAgXSwKICAidXJsIjogImh0dHBzOi8vZ2l0aHViLmNvbS9rZXZpbnBpdGEvY29kZXgtdXNhZ2UtZXh0ZW5zaW9uIiwKICAidXVpZCI6ICJjb2RleC11c2FnZUBrZXZpbnBpdGEuZGV2IiwKICAidmVyc2lvbiI6IDEKfQ==";
      };

      claudeUsageExtension = pkgs.gnomeExtensions.buildShellExtension {
        uuid = "claude-usage@dvdstelt.github.io";
        name = "Claude Code Usage Monitor";
        pname = "claude-usage";
        description = "Shows your Claude subscription tier and live usage limits (5-hour and 7-day windows) in the top bar. Reads your existing Claude Code credentials; no extra login required.";
        link = "https://extensions.gnome.org/extension/10086/claude-code-usage-monitor/";
        version = 7;
        sha256 = "sha256-S47pxAS0T8bu4PWSCrklzRa45hkZfo6KzecpwQ7+lJg=";
        metadata = "ewogICJfZ2VuZXJhdGVkIjogIkdlbmVyYXRlZCBieSBTd2VldFRvb3RoLCBkbyBub3QgZWRpdCIsCiAgImRlc2NyaXB0aW9uIjogIlNob3dzIHlvdXIgQ2xhdWRlIHN1YnNjcmlwdGlvbiB0aWVyIGFuZCBsaXZlIHVzYWdlIGxpbWl0cyAoNS1ob3VyIGFuZCA3LWRheSB3aW5kb3dzKSBpbiB0aGUgdG9wIGJhci4gUmVhZHMgeW91ciBleGlzdGluZyBDbGF1ZGUgQ29kZSBjcmVkZW50aWFsczsgbm8gZXh0cmEgbG9naW4gcmVxdWlyZWQuIiwKICAiZG9uYXRpb25zIjogewogICAgInBheXBhbCI6ICJkdmRzdGVsdCIKICB9LAogICJuYW1lIjogIkNsYXVkZSBDb2RlIFVzYWdlIE1vbml0b3IiLAogICJzZXR0aW5ncy1zY2hlbWEiOiAib3JnLmdub21lLnNoZWxsLmV4dGVuc2lvbnMuY2xhdWRlLXVzYWdlIiwKICAic2hlbGwtdmVyc2lvbiI6IFsKICAgICI0OCIsCiAgICAiNDkiLAogICAgIjUwIgogIF0sCiAgInVybCI6ICJodHRwczovL2dpdGh1Yi5jb20vZHZkc3RlbHQvQ2xhdWRlQ29kZVVzYWdlIiwKICAidXVpZCI6ICJjbGF1ZGUtdXNhZ2VAZHZkc3RlbHQuZ2l0aHViLmlvIiwKICAidmVyc2lvbiI6IDcsCiAgInZlcnNpb24tbmFtZSI6ICIxLjEuMSIKfQ==";
      };
    in
    {
      home-manager.users.${username} = {
        home.packages = with pkgs; [
          gnomeExtensions.caffeine
          gnomeExtensions.tailscale-status
          claudeUsageExtension
          codexUsageExtension
        ];
      };
    };
}
