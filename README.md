# MEDora documentation and deployment

This public repository serves the MEDora documentation with GitHub Pages and
provides public installer releases. Documentation and `install.sh` are synced
from the private `CyberspaceConsulting/MEDora` repository. Release artifacts
contain no application source; the private GHCR images are available only
through the license-authorized registry proxy.

See the [MEDora documentation](https://cyberspaceconsulting.github.io/medora-deploy/)
for setup and operations. To install the latest stable release, run this from
an interactive terminal with Docker Compose v2 and `uuidgen` installed:

```sh
curl --fail --location --silent --show-error https://raw.githubusercontent.com/CyberspaceConsulting/medora-deploy/main/install.sh | sh
```

The installer selects the tag in `current-release` and prompts for a license
key before requesting access to private images. MEDora's release workflow
publishes installer artifacts and updates that pointer. The Pages workflow
publishes `docs/` from the `main` branch.

Before the first deployment, a repository administrator must enable GitHub
Pages in the repository settings and select GitHub Actions as the build source.
The workflow token cannot enable Pages itself.
