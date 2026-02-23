# premyom-jupyter

Service JupyterLab "Premyom" pour Onyxia.

## Image

- Image: `harbor.lan/premyom/onyxia-jupyter:<tag>`
- Sources image: `premyom-jupyter/image/`
- Runtime inclus: `python3.12`, `pip`, `conda` (Miniforge), `jupyterlab`
- Démarrage service: process Jupyter lancé sous l'utilisateur `onyxia`

## SSO

Par défaut ce chart utilise `sso.mode=embedded` (un `oauth2-proxy` dédié par service).

Le callback OIDC est centralisé sur:

`https://datalab.arkam-group.com/premyom-oauth2/<release>/callback`

Pour les détails et le debug, voir `SSO.md` à la racine du repo.

## Release fiable (dockerbuild + ChartMuseum)

Script recommandé:

```bash
cd ~/onyxia-helm-charts
git pull --ff-only
IMG_TAG=0.1.0 CHART_VERSION=0.1.0 ./premyom-jupyter/release_chartmuseum.sh
```

Le script:
- met à jour `values.yaml`, `values.schema.json`, `Chart.yaml`,
- build/push l'image Harbor,
- teste l'image (`python3.12`, `conda`, `jupyter lab`, `nano`),
- package le chart,
- vérifie le contenu du `.tgz` (repository/tag image + version chart),
- push vers ChartMuseum puis vérifie `index.yaml`.

Ensuite (arkam-master) :

```bash
k -n onyxia rollout restart deploy/onyxia-api
k -n onyxia rollout status deploy/onyxia-api --timeout=180s
```

## Contrôle rapide après lancement

```bash
kubectl -n onyxia get pods --sort-by=.metadata.creationTimestamp | grep premyom-jupyter | tail -n 4
kubectl -n onyxia logs deploy/<release> --since=10m | tail -n 120
kubectl -n onyxia logs deploy/<release>-oauth2-proxy --since=10m | tail -n 120
```

Note : si le service n’apparaît pas immédiatement dans l’UI, vérifier d’abord
`/api/public/catalogs` puis faire un hard refresh navigateur.

Runbook exploitation (tunnel/kubectl/checks) : `../OPERATIONS.md`.
