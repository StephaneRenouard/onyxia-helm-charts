# premyom-code-server

Workspace code-server “Premyom” pour Onyxia.

## Image

- Image: `harbor.lan/premyom/onyxia-code-server:<tag>`
- Sources image: `premyom-code-server/image/`
- Runtime inclus: `code-server`, `python3.12`, `pip`, `conda` (Miniforge)
- Démarrage service: process `code-server` lancé sous l’utilisateur `onyxia`
- Defaults IDE: thème sombre + workspace trust désactivé par défaut (pas de popup initiale)

## SSO

Par défaut ce chart utilise `sso.mode=embedded` (un `oauth2-proxy` dédié par workspace).

Le callback OIDC est **centralisé** sur :

`https://datalab.arkam-group.com/premyom-oauth2/<release>/callback`

Raison : Keycloak n’accepte pas de façon fiable un wildcard sur le host (ex: `https://*.datalab.../oauth2/callback`), ce qui
provoque `Invalid parameter: redirect_uri`.

Pour les détails et le debug, voir `SSO.md` à la racine du repo.

## Release fiable (dockerbuild + ChartMuseum)

Problème récurrent évité par cette procédure:
- chart packagé avec une mauvaise image (ex: `0.1.18` au lieu de `0.1.21`),
- puis pods lancés avec une ancienne image malgré un build récent.

Script recommandé (fait les contrôles bloquants avant upload):

```bash
cd ~/onyxia-helm-charts
git pull --ff-only
IMG_TAG=0.1.21 CHART_VERSION=0.2.52 ./premyom-code-server/release_chartmuseum.sh
```

Le script:
- met à jour `values.yaml`, `values.schema.json`, `Chart.yaml`,
- build/push l’image Harbor,
- teste l’image (`python3.12`, `conda`, `nano`),
- package le chart,
- vérifie le contenu du `.tgz` (image/tag + version chart),
- push vers ChartMuseum puis vérifie `index.yaml`.

Ensuite (arkam-master):

```bash
k -n onyxia rollout restart deploy/onyxia-api
k -n onyxia rollout status deploy/onyxia-api --timeout=180s
```
