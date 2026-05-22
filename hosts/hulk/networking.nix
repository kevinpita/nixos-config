_: {
  networking.useDHCP = false;
  networking.interfaces.eno1 = {
    ipv4.addresses = [
      {
        address = "192.168.0.3";
        prefixLength = 24;
      }
    ];
  };
  networking.defaultGateway = "192.168.0.1";
}
