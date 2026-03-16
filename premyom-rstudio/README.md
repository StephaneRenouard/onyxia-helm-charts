# premyom-rstudio

> WIP: premier scaffold du service RStudio Premyom (SSO + montages S3 + image dédiée).

Service RStudio Server "Premyom" pour Onyxia.

## Image

- Image: `harbor.lan/premyom/onyxia-rstudio:<tag>`
- Sources image: `premyom-rstudio/image/`
- Runtime inclus: `R 4.5` + `RStudio Server`
- Démarrage service: process `rserver` (port `8080`)

## SSO

Par défaut ce chart utilise `sso.mode=embedded` (oauth2-proxy dédié au service).
Ce choix évite les boucles de redirection observées en Safari + iframe avec `forwardAuth`.
En mode `embedded`, le chart force `oauth2-proxy --cookie-samesite=none` pour Safari/iframe.

Le chart force aussi des options `rserver` compatibles iframe Safari:
- `--www-same-site=none`
- `--auth-cookies-force-secure=0` (par défaut)
- `--www-verify-user-agent=0` (évite les faux "unsupported browser" sur versions Safari récentes)

Ces options sont pilotables via `rstudio.server.sameSite`, `rstudio.server.forceSecureCookies` et `rstudio.server.verifyUserAgent`.

Les probes Kubernetes utilisent `/unsupported_browser.htm` (200 statique), pour éviter les boucles de redirection `/` quand les cookies `Secure` sont activés.

Le callback OIDC est centralisé sur:

`https://datalab.arkam-group.com/premyom-oauth2/<release>/callback`

Pour les détails et le debug, voir `SSO.md` à la racine du repo.

## Release fiable (dockerbuild + ChartMuseum)

Script recommandé:

```bash
cd ~/onyxia-helm-charts
git pull --ff-only
IMG_TAG=0.1.0 CHART_VERSION=0.1.0 ./premyom-rstudio/release_chartmuseum.sh
```

Le script:
- met à jour `values.yaml`, `values.schema.json`, `Chart.yaml`,
- build/push l'image Harbor,
- teste l'image (`R --version`, `rserver`, `nano`),
- package le chart,
- vérifie le contenu du `.tgz` (repository/tag image + version chart),
- push vers ChartMuseum puis vérifie `index.yaml`.

Par défaut, les scripts image tournent en `docker build --no-cache --pull`
(`DOCKER_NO_CACHE=true`, `DOCKER_PULL=true`) pour éviter les builds incohérents.
Tu peux forcer le cache avec `DOCKER_NO_CACHE=false`.

Ensuite (arkam-master) :

```bash
k -n onyxia rollout restart deploy/onyxia-api
k -n onyxia rollout status deploy/onyxia-api --timeout=180s
```

## Contrôle rapide après lancement

```bash
kubectl -n onyxia get pods --sort-by=.metadata.creationTimestamp | grep premyom-rstudio | tail -n 4
kubectl -n onyxia logs deploy/<release> --since=10m | tail -n 120
kubectl -n onyxia logs deploy/<release>-oauth2-proxy --since=10m | tail -n 120
```

Note : si le service n’apparaît pas immédiatement dans l’UI, vérifier d’abord
`/api/public/catalogs` puis faire un hard refresh navigateur.

Runbook exploitation (tunnel/kubectl/checks) : `../OPERATIONS.md`.
