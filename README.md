# onyxia-helm-charts

Repo Helm (GitHub Pages) pour des charts “wrapper” Onyxia (ex. images IDE custom).

Conventions images : `IMAGES.md`.

## Utilisation

```bash
helm repo add premyom https://stephanerenouard.github.io/onyxia-helm-charts
helm search repo premyom
helm show values premyom/premyom-code-server
helm show values premyom/premyom-s3-explorer
```

## Release (chart wrapper)

Le repo contient des charts wrapper (catalogue Onyxia “Premyom Workspaces”) :
- `premyom-code-server` (workspace VS Code)
- `premyom-s3-explorer` (explorateur `/mnt/s3` via Filebrowser)

En production / démo, le packaging & la distribution du chart sont faits via ChartMuseum (Harbor).

Notes:
- Garder uniquement les dépendances packagées en `*.tgz` dans `premyom-code-server/charts/` (ex: `vscode-python-2.4.2.tgz`), ne pas committer une copie extraite du chart (sinon Helm peut utiliser le dossier et casser la résolution des dépendances).
