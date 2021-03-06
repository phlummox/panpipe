# Used for building and testing on Hydra

# Provides a bunch of nixpkgs versions, augmented with useful helper functions
with builtins;
with rec {
  pinnedConfig = (import <nixpkgs> { config = {}; }).fetchgit {
    url    = http://chriswarbo.net/git/nix-config.git;
    rev    = "7b96c3a";
    sha256 = "0sqhf599ll2qshbnmspni5r3h5mfwbbkyz5xhfb3jxhflba594zw";
  };

  pkgSets = { pinnedConfig = import pinnedConfig {}; } //
    (with tryEval <nix-config>;
     if success
        then { pathConfig = import value {}; }
        else {});

};

with pkgSets.pinnedConfig.nixpkgs1709.lib;
with rec {
  # "self" is a customised nixpkgs set, "super" is the corresponding original
  buildForNixpkgs = self: super: mapAttrs (_: buildForHaskell self)
                                          super.haskell.packages;

  buildForHaskell = pkgs: hsPkgs: rec {
    # Uses Haskell package set provided by nixpkgs
    nixpkgsExpr  = pkgs.runCabal2nix { url = ./.; };   # Useful GC root
    nixpkgsDeps  = hsPkgs.callPackage nixpkgsExpr {};  # Actual Haskell build

    # Uses a Cabal sandbox to pick dependencies from (a snapshot of) Hackage
    hackageDeps = pkgs.haskellPkgWithDeps {
      inherit hsPkgs;
      delay-failure = true;
      dir           = ./.;
    };
  };

  buildForPkgSet = pkgSet:
    mapAttrs (name: self: buildForNixpkgs self (getAttr name pkgSet))
             pkgSet.customised;
};
mapAttrs (_: buildForPkgSet) pkgSets
