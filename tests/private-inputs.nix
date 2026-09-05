let
  complete = ./fixtures/private-inputs/complete;
  dummy = ../ci-dummy-input;
  load =
    secrets: work:
    import ../lib/private-inputs.nix {
      inherit secrets work;
      username = "test-user";
    };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
in
{
  real-inputs = !(load complete complete).ciMode;
  public-inputs = (load dummy dummy).ciMode;
  rejects-dummy-secrets-only = rejects (load dummy complete);
  rejects-dummy-work-only = rejects (load complete dummy);
  rejects-missing-common-secrets = rejects (load ./fixtures/private-inputs/missing-module complete);
  rejects-missing-work-module = rejects (load complete ./fixtures/private-inputs/missing-module);
  rejects-invalid-work-module = rejects (load complete ./fixtures/private-inputs/invalid-module);
}
