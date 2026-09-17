# Selfhostix

**Selfhostix** provides reproducible NixOS deployments of [La Suite numérique](https://github.com/suitenumerique) services.

Each service runs inside a lightweight NixOS MicroVM using [`microvm.nix`](https://github.com/microvm-nix/microvm.nix), with its infrastructure defined declaratively through Nix flakes.

The project aims to make self-hosting La Suite services simple, isolated, reproducible and easy to experiment with.

Related upstream work also includes [La Suite Drive #841](https://github.com/suitenumerique/drive/pull/841) and [Grist #2596](https://github.com/gristlabs/grist-core/pull/2596), contributing to improved Nix infrastructure across the ecosystem.

## Contributors

Special thanks to [@youpaw](https://github.com/youpaw) for the exploratory [`dinum-demo`](https://github.com/youpaw/dinum-demo) project, which provided valuable groundwork for Selfhostix.

Many thanks as well to [@navysubmarine](https://github.com/navysubmarine), [@SystemicYogi](https://github.com/SystemicYogi), [@youpaw](https://github.com/youpaw), and [@jb255](https://github.com/jb255) for their contributions, reviews and technical discussions.
