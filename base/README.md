# base

Base d’images “workspaces” indépendantes (sans `inseefrlab/*`), destinées à être consommées par les charts IDE Onyxia (ex: `vscode-python`).

## Image `code-server`

Fichiers:
- `base/code-server.dockerfile`
- `base/entrypoint.sh`
- `base/build.sh`
- `base/build_and_push.sh`

Contrat minimal visé (compat Onyxia + chart `vscode-python`):
- script `/opt/onyxia-init.sh` présent (le chart lance `/opt/onyxia-init.sh <cmd...>`)
- écoute sur `0.0.0.0:8080`
- auth:
  - par défaut: mot de passe via la variable d’env `PASSWORD`
  - optionnel: désactivation via `CODE_SERVER_AUTH=none` (utile si l’accès est protégé par SSO en amont)
- workspace par défaut: `/home/onyxia/work`
- user: `onyxia`

### Build & push (machine de build)

Via les scripts:

```bash
cd onyxia-helm-charts/base

export IMAGE_REPOSITORY="onyxia-code-server"
export IMAGE_TAG="0.1.3"
export CODE_SERVER_VERSION="4.106.3"

./build.sh
# ou
./build_and_push.sh
```

Exemple Harbor (registry locale) :

```bash
cd onyxia-helm-charts/base

export IMAGE_REGISTRY_HOST="harbor.lan"
export IMAGE_NAMESPACE="premyom"
export IMAGE_TAG="0.1.3"

docker login harbor.lan
./build_and_push.sh
```

En direct (équivalent):

```bash
cd onyxia-helm-charts

IMAGE_REPOSITORY="harbor.lan/premyom/onyxia-code-server"
IMAGE_TAG="0.1.3"

docker build \
  -f base/code-server.dockerfile \
  --build-arg CODE_SERVER_VERSION=4.106.3 \
  -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" .
docker push "${IMAGE_REPOSITORY}:${IMAGE_TAG}"
```

Note: le Dockerfile installe le paquet `code-server_*_${ARCH}.deb` en détectant l’arch via `dpkg --print-architecture` (ex: `amd64`, `arm64`).

### Utilisation via le wrapper `premyom-vscode-python`

Dans Onyxia, dans les valeurs du service, surcharger:

```yaml
vscode-python:
  service:
    image:
      custom:
        enabled: true
        version: harbor.lan/premyom/onyxia-code-server:0.1.3
```

### Utilisation via le wrapper `premyom-code-server` (SSO / sans mot de passe)

- Ce chart ajoute l’annotation Traefik `forwardAuth` et positionne `CODE_SERVER_AUTH=none`.
- Pour éviter la “surcouche” d’un tag Docker déjà pull sur un nœud, préfère incrémenter le tag (ex: `0.1.2`) ou utiliser `image.pullPolicy: Always`.

### Dépannage

- Si tu vois `/opt/onyxia-init.sh: not found`, l’image n’est pas compatible avec le chart IDE Onyxia: ce script doit exister (même en stub).
