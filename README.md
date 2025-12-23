# onyxia-helm-charts

Repo Helm (GitHub Pages) pour des charts “wrapper” Onyxia (ex. images IDE custom).

## Utilisation

```bash
helm repo add premyom https://stephanerenouard.github.io/onyxia-helm-charts
helm search repo premyom
helm show values premyom/premyom-vscode-python
```

## Release (chart wrapper)

Le repo est un “Helm repo” statique :
- un archive `*.tgz` par version
- `index.yaml` à jour (URLs + `digest` sha256)

Workflow minimal (sans `helm package`) :
```bash
VERSION="0.1.8"
tar -czf "premyom-vscode-python-${VERSION}.tgz" premyom-vscode-python
shasum -a 256 "premyom-vscode-python-${VERSION}.tgz"
```

Ensuite, ajouter l’entrée correspondante dans `index.yaml` (version, url, digest, created) et publier.
