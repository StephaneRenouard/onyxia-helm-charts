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

## Image `filebrowser` (S3 Explorer)

Explorateur de fichiers web basé sur Filebrowser, destiné à exposer `/mnt/s3` via SSO (oauth2-proxy) et montages S3 (s3fs) basés sur les groupes Keycloak.

Fichier:
- `base/filebrowser.dockerfile`

Build :
```bash
cd onyxia-helm-charts/base
export DOCKERFILE="filebrowser.dockerfile"
export IMAGE_REPOSITORY="stephanerenouard/onyxia-s3-explorer"
export IMAGE_TAG="0.1.0"
./build_and_push.sh
```

## Image `code-server-python`

Variante “code-server + Python” (sans `inseefrlab/*`), utile si tu veux une image “IDE Python” indépendante.

Fichier:
- `base/code-server-python.dockerfile`

Build :
```bash
cd onyxia-helm-charts/base
export DOCKERFILE="code-server-python.dockerfile"
export IMAGE_REGISTRY_HOST="harbor.lan" IMAGE_NAMESPACE="premyom"
export IMAGE_NAME="onyxia-vscode-python" IMAGE_TAG="0.1.0"
./build_and_push.sh
```

### Build & push (machine de build)

Via les scripts:

```bash
cd onyxia-helm-charts/base

export IMAGE_REPOSITORY="stephanerenouard/onyxia-code-server"
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

### Historique (wrapper `premyom-vscode-python`)

Ce chart n’est plus maintenu dans ce repo (historique).
La voie recommandée est d’utiliser `premyom-code-server` (SSO + montages S3).

Si besoin ponctuel, la même surcouche d’image peut être appliquée au chart upstream `vscode-python`.

### Utilisation via le wrapper `premyom-code-server` (SSO / sans mot de passe)

- Ce chart ajoute l’annotation Traefik `forwardAuth` et positionne `CODE_SERVER_AUTH=none`.
- Pour éviter la “surcouche” d’un tag Docker déjà pull sur un nœud, préfère incrémenter le tag (ex: `0.1.2`) ou utiliser `image.pullPolicy: Always`.

### Dépannage

- Si tu vois `/opt/onyxia-init.sh: not found`, l’image n’est pas compatible avec le chart IDE Onyxia: ce script doit exister (même en stub).
