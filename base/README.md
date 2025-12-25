# base

Base d’images “workspaces” indépendantes (sans `inseefrlab/*`), destinées à être consommées par les charts IDE Onyxia (ex: `vscode-python`).

## Image `code-server`

Fichiers:
- `base/code-server.dockerfile`
- `base/entrypoint.sh`

Contrat minimal visé (compat Onyxia + chart `vscode-python`):
- écoute sur `0.0.0.0:8080`
- auth par mot de passe via la variable d’env `PASSWORD`
- workspace par défaut: `/home/onyxia/work`
- user: `onyxia`

### Build & push (ex sur une machine de build)

```bash
cd onyxia-helm-charts

IMAGE_REPOSITORY="stephanerenouard/onyxia-code-server"
IMAGE_TAG="0.1.0"

docker build \
  -f base/code-server.dockerfile \
  --build-arg CODE_SERVER_VERSION=4.106.3 \
  -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" .
docker push "${IMAGE_REPOSITORY}:${IMAGE_TAG}"
```

Note: le Dockerfile installe le paquet `*_amd64.deb`. Si tu builds sur une machine ARM (M1/M2/M3), il faudra soit builder en `--platform linux/amd64`, soit ajouter une variante `arm64`.

### Utilisation via le wrapper `premyom-vscode-python`

Dans Onyxia, dans les valeurs du service, surcharger:

```yaml
vscode-python:
  service:
    image:
      custom:
        enabled: true
        version: stephanerenouard/onyxia-code-server:0.1.0
```
