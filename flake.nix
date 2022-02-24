{
  description = "Shell-Run is a tool for ergonomically running shell commands.";
  inputs = {
    algebra-simple-src.url = "github:tbidne/algebra-simple/main";
    flake-utils.url = "github:numtide/flake-utils";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    # See https://discourse.nixos.org/t/nix-2-6-0-released/17324/8
    haskellNix.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.follows = "haskellNix/nixpkgs-2111";
    refined-extras-src.url = "github:tbidne/refined-extras/main";
  };
  outputs =
    { algebra-simple-src
    , flake-utils
    , haskellNix
    , nixpkgs
    , refined-extras-src
    , self
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      overlays = [
        haskellNix.overlay
        (final: prev: {
          # This overlay adds our project to pkgs
          shellRunProject =
            final.haskell-nix.project' {
              src = ./.;
              compiler-nix-name = "ghc8107";

              # This is needed because cabal.project and stack.yaml
              # both exist in this repo.
              projectFileName = "cabal.project";
            };

          algebra-simple = final.cabal2nix "algebra-simple" algebra-simple-src { };
          refined-extras = final.cabal2nix "refined-extras" refined-extras-src { };
        })
      ];
      pkgs = import nixpkgs { inherit system overlays; };
      flake = pkgs.shellRunProject.flake { };
    in
    flake // {
      defaultPackage = flake.packages."shell-run:exe:shell-run";

      devShell = pkgs.shellRunProject.shellFor {
        tools = {
          cabal-install = { };
          haskell-language-server = { };
          ghcid = { };
        };
      };
    });
}
