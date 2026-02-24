# premyom-slicer (POC)

Service Onyxia **3D Slicer** (desktop web via noVNC/websockify), orienté POC CPU-only pour segmentation DICOM.

## Objectif POC

- SSO intégré (pattern Premyom)
- montages S3 par groupes Keycloak (`/mnt/s3`)
- accès web (desktop distant) depuis Onyxia
- sizing initial : `8-12 vCPU`, `16Gi` RAM, `worker1`

## Image / chart

- Image : `harbor.lan/premyom/onyxia-slicer:<tag>`
- Chart : `premyom-slicer`
- Source image : `premyom-slicer/image/`

## Paramètres importants

- `resources.*` : défaut POC CPU-only (`requests.cpu=8`, `limits.cpu=12`, `memory=16Gi`)
- `nodeSelector.kubernetes.io/hostname=worker1`
- `workspace.emptyDir.sizeLimit=50Gi`
- `slicer.releaseSeries` : série de release 3D Slicer (ex `5.8`)
- `slicer.downloadUrl` : override URL de téléchargement (si besoin)
- `slicer.web.resizeMode` : `scale` / `remote` / `off` (UX noVNC)
- `slicer.display.width` / `slicer.display.height` : résolution desktop virtuelle

## Release (dockerbuild -> Harbor -> ChartMuseum)

```bash
IMG_TAG=0.1.0 CHART_VERSION=0.1.0 ./premyom-slicer/release_chartmuseum.sh
```

Variables utiles:

```bash
SLICER_VERSION=5.8 IMG_TAG=0.1.0 CHART_VERSION=0.1.0 ./premyom-slicer/release_chartmuseum.sh
```

## Notes techniques

- Le build télécharge 3D Slicer depuis `download.slicer.org` (release Linux).
- Le service expose noVNC/websockify sur le port `8080`.
- Readiness/liveness probe sur `/vnc.html`.
- POC **CPU-only** (pas de GPU Kubernetes détecté sur `worker1` à date).

## Validation POC (Essilor)

- chargement DICOM (~1.2 Go) depuis S3 vers scratch local session
- segmentation dans Slicer
- export `.stl` / `.obj` vers S3
- test avec 2 sessions simultanées
