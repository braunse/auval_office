{ sources ? import ./nix/sources.nix
, pkgs ? import sources.nixpkgs {}
, erlang ? pkgs.erlangR23
, elixir ? pkgs.beam.packages.erlangR23.elixir_1_11 }:
pkgs.mkShell {
  buildInputs = [
    pkgs.nodejs-12_x
    pkgs.nodePackages.node2nix

    erlang
    elixir

    # keep this line if you use bash
    pkgs.bashInteractive
  ];

  shellHook = ''
    export ERL_INCLUDE_PATH="${pkgs.erlang}/lib/erlang/usr/include"
  '';
}
