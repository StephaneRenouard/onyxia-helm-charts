# Operations — Premyom services (Arkam)

Ce document regroupe les procédures d’exploitation utilisées en live pour les services `premyom-*`.

## 1) Accès cluster (kubectl) depuis le poste local

Tunnel SSH (à lancer sur la machine locale) :

```bash
ssh -N -L 6443:192.168.1.120:6443 stef@datalab.handco.fr
```

Variante recommandée (datalab): `./open_tunnel.sh` ouvre aussi les forwards SSH utiles:

- `22105` -> `dockerbuild` (`192.168.1.105`)
- `22120` -> `arkam-master` (`192.168.1.120`)
- `22130` -> `master-premyom` (`192.168.1.130`)
- `22106` -> `harbor` (`192.168.1.106`)
- `22200` -> `worker1` (`192.168.1.200`)
- `22101` -> `HAProxy` (`192.168.1.101`)

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
- Les scripts release valident que `DOCKER_NO_CACHE` / `DOCKER_PULL` valent strictement `true|false`.
- Les scripts release vérifient que le daemon Docker est disponible avant le build.
- Les scripts release affichent explicitement les flags Docker effectivement appliqués.
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
IMG_TAG=0.1.5 CHART_VERSION=0.1.4 ./premyom-jupyter/release_chartmuseum.sh
```

### `premyom-rstudio`

```bash
cd ~/onyxia-helm-charts
IMG_TAG=0.1.1 CHART_VERSION=0.1.0 ./premyom-rstudio/release_chartmuseum.sh
```

### `premyom-s3-explorer`

```bash
cd ~/onyxia-helm-charts
IMG_TAG=0.1.9 CHART_VERSION=0.1.58 ./premyom-s3-explorer/release_chartmuseum.sh
```

### `premyom-slicer`

```bash
cd ~/onyxia-helm-charts
IMG_TAG=0.1.39 CHART_VERSION=0.1.37 ./premyom-slicer/release_chartmuseum.sh
```

Option debug (réactiver le cache explicitement, déconseillé en release):

```bash
DOCKER_NO_CACHE=false DOCKER_PULL=false IMG_TAG=... CHART_VERSION=... ./premyom-*/release_chartmuseum.sh
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
