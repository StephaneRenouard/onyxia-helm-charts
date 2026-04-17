# premyom-s3-explorer

Explorateur de fichiers basé sur Filebrowser, exposant le contenu monté sous `/mnt/s3`.
Téléchargement désactivé via `filebrowser config init/set --perm.download=false` dans `premyom-s3-explorer/image/onyxia-init.sh`.
Un éditeur tabulaire intégré est exposé sur `/tabular/` pour lire/éditer `csv`, `xls`, `xlsx`.
L’écriture dépend des droits du mount S3 (`_rw` modifiable, `_ro` lecture seule).
Depuis l’UI Filebrowser, un bouton flottant `Éditeur CSV/XLS/XLSX` est injecté.
Quand l’URL contient un fichier `csv/xls/xlsx`, redirection automatique vers l’éditeur tabulaire.

## Image

- Image: `harbor.lan/premyom/onyxia-s3-explorer:<tag>`
- Sources image: `premyom-s3-explorer/image/`

## SSO

Par défaut ce chart utilise `sso.mode=embedded` (un `oauth2-proxy` dédié par service).

Le callback OIDC est **centralisé** sur :

`https://datalab.arkam-group.com/premyom-oauth2/<release>/callback`

Pour les détails et le debug, voir `SSO.md` à la racine du repo.

## Release fiable (dockerbuild + ChartMuseum)

Script recommandé :

```bash
cd ~/onyxia-helm-charts
git pull --ff-only
IMG_TAG=0.1.7 CHART_VERSION=0.1.50 ./premyom-s3-explorer/release_chartmuseum.sh
```

Le build image est maintenant en `--no-cache --pull` par défaut
(`DOCKER_NO_CACHE=true`, `DOCKER_PULL=true`) pour garantir un rebuild réel.
Tu peux réactiver le cache avec `DOCKER_NO_CACHE=false`.

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
