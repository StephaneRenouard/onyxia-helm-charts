# premyom-s3-explorer

Explorateur de fichiers basé sur Filebrowser, exposant le contenu monté sous `/mnt/s3`.

## Image

- Image: `harbor.lan/premyom/onyxia-s3-explorer:<tag>`
- Sources image: `premyom-s3-explorer/image/`

## SSO

Par défaut ce chart utilise `sso.mode=embedded` (un `oauth2-proxy` dédié par service).

Le callback OIDC est **centralisé** sur :

`https://datalab.arkam-group.com/premyom-oauth2/<release>/callback`

Pour les détails et le debug, voir `SSO.md` à la racine du repo.

## Release fiable (dockerbuild + ChartMuseum)

Ce chart n’a pas encore de script `release_chartmuseum.sh` dédié.

Séquence recommandée :

```bash
cd ~/onyxia-helm-charts/premyom-s3-explorer/image
IMAGE_REGISTRY_HOST=harbor.lan IMAGE_NAMESPACE=premyom IMAGE_TAG=0.1.7 FILEBROWSER_VERSION=2.57.1 ./build_and_push.sh

cd ~/onyxia-helm-charts
helm package premyom-s3-explorer --version 0.1.50 --app-version latest
curl --fail-with-body --data-binary "@premyom-s3-explorer-0.1.50.tgz" http://192.168.1.106:8081/api/charts
```

Puis refresh catalogue Onyxia :

```bash
k -n onyxia rollout restart deploy/onyxia-api
k -n onyxia rollout status deploy/onyxia-api --timeout=180s
```

## Contrôle rapide après lancement

```bash
kubectl -n onyxia get pods --sort-by=.metadata.creationTimestamp | grep premyom-s3-explorer | tail -n 6
kubectl -n onyxia logs deploy/<release>-oauth2-proxy --since=10m | tail -n 120
kubectl -n onyxia logs deploy/<release> --since=10m | tail -n 120
```

Runbook exploitation (tunnel/kubectl/checks) : `../OPERATIONS.md`.
