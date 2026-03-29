{
  description = "Tembo-ready development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_20
          pnpm
          python311
          git
        ];
        shellHook = ''
          echo "Tembo VM shell ready"
        '';
      };
    };
}
