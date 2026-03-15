# Operations — Premyom services (Arkam)

Ce document regroupe les procédures d’exploitation utilisées en live pour les services `premyom-*`.

## 1) Accès cluster (kubectl) depuis le poste local

Tunnel SSH (à lancer sur la machine locale) :

```bash
ssh -N -L 6443:192.168.1.120:6443 stef@datalab.handco.fr
```

Vérification rapide :

```bash
K=/Users/stef/Workspace/tools/bin/kubectl
KCFG=/Users/stef/Workspace/tools/kubeconfig-arkam-tunnel.yaml
"$K" --kubeconfig "$KCFG" get nodes -o wide
"$K" --kubeconfig "$KCFG" -n onyxia get pods -o wide
```

Si `bind [127.0.0.1]:6443: Address already in use` :

```bash
lsof -nP -iTCP:6443 -sTCP:LISTEN
```

## 2) Accès cluster depuis `arkam-master`

Sur `arkam-master`, utiliser le raccourci shell :

```bash
echo "alias k='sudo k3s kubectl'" >> ~/.bashrc
source ~/.bashrc
k -n onyxia get pods
```

## 3) Release fiable sur `dockerbuild` (192.168.1.105)

Pré-check recommandé :

```bash
cd ~/onyxia-helm-charts
git status --short
```

Si le repo n’est pas propre, éviter `git pull --ff-only` direct.

Règle de release (critique) :

- Si un changement touche une **image** (Dockerfile, `onyxia-init.sh`, entrypoint, scripts image), **toujours bump `IMG_TAG`**.
- Un repush du même tag peut être ignoré par les nœuds Kubernetes si l’image est déjà présente localement (`IfNotPresent`).
- Si un changement touche uniquement les templates/values/chart, bump `CHART_VERSION` suffit.

Durcissement process (global `premyom-*`) :

- Les scripts image buildent par défaut en `docker build --no-cache --pull`.
- Chaque image embarque les labels:
  - `io.premyom.git-commit`
  - `io.premyom.image-source-sha` (hash du dossier `image/`).
- Chaque `release_chartmuseum.sh` vérifie ces labels après build.
- Si les labels ne correspondent pas au code source courant, la release échoue avant packaging/push chart.
- Objectif: éviter le cas “chart publié mais patch absent de l’image”.

### `premyom-code-server`

```bash
cd ~/onyxia-helm-charts
git pull --ff-only
IMG_TAG=0.1.27 CHART_VERSION=0.2.59 ./premyom-code-server/release_chartmuseum.sh
```

Validation post-release (recommandée) :

```bash
curl -fsSL http://192.168.1.106:8081/index.yaml | grep -n 'premyom-code-server-0.2.59.tgz'
```

### `premyom-jupyter`

```bash
cd ~/onyxia-helm-charts
IMG_TAG=0.1.0 CHART_VERSION=0.1.0 ./premyom-jupyter/release_chartmuseum.sh
```

### `premyom-rstudio`

```bash
cd ~/onyxia-helm-charts
IMG_TAG=0.1.0 CHART_VERSION=0.1.0 ./premyom-rstudio/release_chartmuseum.sh
```

### `premyom-s3-explorer`

Le service n’a pas encore de script `release_chartmuseum.sh` dédié.

```bash
cd ~/onyxia-helm-charts/premyom-s3-explorer/image
IMAGE_REGISTRY_HOST=harbor.lan IMAGE_NAMESPACE=premyom IMAGE_TAG=0.1.7 FILEBROWSER_VERSION=2.57.1 ./build_and_push.sh

cd ~/onyxia-helm-charts
helm package premyom-s3-explorer --version 0.1.50 --app-version latest
curl --fail-with-body --data-binary "@premyom-s3-explorer-0.1.50.tgz" http://192.168.1.106:8081/api/charts
```

## 4) Forcer le refresh catalogue Onyxia

Après publication d’un chart :

```bash
K=/Users/stef/Workspace/tools/bin/kubectl
KCFG=/Users/stef/Workspace/tools/kubeconfig-arkam-tunnel.yaml
"$K" --kubeconfig "$KCFG" -n onyxia rollout restart deploy/onyxia-api
"$K" --kubeconfig "$KCFG" -n onyxia rollout status deploy/onyxia-api --timeout=180s
```

Validation API (catalogue vu par Onyxia) :

```bash
curl -sk https://datalab.arkam-group.com/api/public/catalogs \
  | jq -r '.catalogs[] | select(.id=="premyom") | .catalog.latestPackages | keys[]' \
  | sort
```

Note UI : un chart peut être visible côté API mais absent temporairement côté navigateur (cache/session front).  
Faire un hard refresh (`Cmd+Shift+R`) ou reconnecter la session.

## 5) Checks runtime après lancement d’un service

Derniers pods :

```bash
K=/Users/stef/Workspace/tools/bin/kubectl
KCFG=/Users/stef/Workspace/tools/kubeconfig-arkam-tunnel.yaml
"$K" --kubeconfig "$KCFG" -n onyxia get pods --sort-by=.metadata.creationTimestamp | tail -n 12
```

Logs Jupyter (dernier lancement) :

```bash
POD=$("$K" --kubeconfig "$KCFG" -n onyxia get pods --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep '^premyom-jupyter-.*-[a-z0-9]\{5\}$' | tail -n 1)
"$K" --kubeconfig "$KCFG" -n onyxia logs "$POD" --tail=200
```

Checks S3 (RW effectif côté pod) :

```bash
POD=$("$K" --kubeconfig "$KCFG" -n onyxia get pods -o name | grep premyom-code-server | grep vscode-python | tail -n 1)
"$K" --kubeconfig "$KCFG" -n onyxia exec -it "$POD" -- mount | grep s3fs || true
"$K" --kubeconfig "$KCFG" -n onyxia exec -it "$POD" -- sh -lc 'id && ls -la /mnt/s3'
```

## 6) SSO/TLS : état validé

- Bug “1er clic KO, 2e clic OK” corrigé sur les charts `premyom-code-server` et `premyom-s3-explorer`.
- TLS wildcard en place pour `datalab.arkam-group.com` et `*.datalab.arkam-group.com` (plus de certificat Traefik par défaut sur les workspaces).
- Les warnings `oauth2-proxy` sur `cookie domain` et `PKCE` vus en logs sont non bloquants dans l’état actuel.

Détails : `SSO.md`.
