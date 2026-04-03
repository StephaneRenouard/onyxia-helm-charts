# premyom-sofa (POC)

Service Onyxia **SOFA Simulation** (desktop web via **Xpra HTML5**), orienté POC CPU-only.

## Objectif POC

- SSO intégré (pattern Premyom)
- montages S3 par groupes Keycloak (`/mnt/s3`)
- accès web (desktop distant) depuis Onyxia
- sizing initial : `8-12 vCPU`, `16Gi` RAM, `worker1`

## Image / chart

- Image : `harbor.lan/premyom/onyxia-sofa:<tag>`
- Chart : `premyom-sofa`
- Source image : `premyom-sofa/image/`

## Paramètres importants

- `resources.*` : défaut POC CPU-only (`requests.cpu=8`, `limits.cpu=12`, `memory=16Gi`)
- `nodeSelector.kubernetes.io/hostname=worker1`
- `workspace.emptyDir.sizeLimit=50Gi`
- `sofa.releaseSeries` : version SOFA (ex `25.12.00`)
- `sofa.downloadUrl` : override URL de téléchargement (si besoin)
- `sofa.web.resizeMode` : `scale` / `remote` / `off` (pilotage du mode d'affichage Xpra côté client ; `remote` traité comme `off`)
- `sofa.display.width` / `sofa.display.height` : résolution desktop virtuelle

## Release (dockerbuild -> Harbor -> ChartMuseum)

Règle de release (critique) :

- Si tu modifies **l’image** (`premyom-sofa/image/Dockerfile`, `onyxia-init.sh`, scripts image), **bump `IMG_TAG`**.
- Sinon Kubernetes peut réutiliser une image déjà présente sur le nœud (`imagePullPolicy: IfNotPresent`) même si le même tag a été repush.
- Si tu modifies seulement le chart/templates/values, un bump `CHART_VERSION` suffit.
- Le build image est forcé en `docker build --no-cache --pull` par défaut (`DOCKER_NO_CACHE=true`, `DOCKER_PULL=true`) pour éviter les faux rebuilds depuis le cache.

```bash
IMG_TAG=0.1.0 CHART_VERSION=0.1.0 ./premyom-sofa/release_chartmuseum.sh
```

Variables utiles:

```bash
SOFA_VERSION=25.12.00 IMG_TAG=0.1.0 CHART_VERSION=0.1.0 ./premyom-sofa/release_chartmuseum.sh
```

## Notes techniques

- Le build télécharge SOFA depuis les releases GitHub `sofa-framework/sofa` (archive Linux).
- Le service expose Xpra HTML5 sur le port `8080`.
- Readiness/liveness probe sur `/`.
- Le viewer HTML5 Xpra est servi sur `/` (redirection OAuth vers `/` ou `/?desktop_scaling=auto` selon `resizeMode`), avec menu flottant et clipboard client désactivés par défaut (`floating_menu=false&clipboard=false`) ; le serveur Xpra est lancé avec `--clipboard=no` et le client HTML reçoit un patch runtime Safari (neutralisation `#pasteboard`, désactivation du `tablet input`, garde `_poll_clipboard` quand `clipboard=false`) pour éviter le toast “Coller”.
- Au démarrage, un helper `wmctrl` tente de maximiser automatiquement la fenêtre `runSofa`.
- POC **CPU-only** (pas de GPU Kubernetes détecté sur `worker1` à date).

## Validation POC (Essilor)

- ouverture de `runSofa` via Xpra HTML5
- ouverture d’une scène `.scn` depuis `/mnt/s3`
- sauvegarde des sorties vers S3 (selon droits `_rw`/`_ro`)
- test avec 2 sessions simultanées
