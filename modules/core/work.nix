{
  inputs,
  username,
  ...
}:
let
  hasWork = inputs ? nixos-work;
  workPath = if hasWork then "${inputs.nixos-work}" else null;
in
{
  imports = if hasWork then [ workPath ] else [ ];
}
