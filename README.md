# onyxia-helm-charts

Repo Helm (GitHub Pages) pour des charts “wrapper” Onyxia (ex. images IDE custom).

## Utilisation

```bash
helm repo add premyom https://stephanerenouard.github.io/onyxia-helm-charts
helm search repo premyom
helm show values premyom/premyom-vscode-python
helm show values premyom/premyom-code-server
```

## Release (chart wrapper)

Le repo est un “Helm repo” statique :
- un archive `*.tgz` par version
- `index.yaml` à jour (URLs + `digest` sha256)

Workflow minimal (sans `helm package`) :
```bash
VERSION="0.1.10"
# Important sur macOS: éviter les xattrs/AppleDouble, sinon Helm peut planter avec:
# "chart illegally contains content outside the base directory"
COPYFILE_DISABLE=1 COPY_EXTENDED_ATTRIBUTES_DISABLE=1 \
  tar --no-xattrs -czf "premyom-vscode-python-${VERSION}.tgz" premyom-vscode-python
shasum -a 256 "premyom-vscode-python-${VERSION}.tgz"
```

Ensuite, ajouter l’entrée correspondante dans `index.yaml` (version, url, digest, created) et publier.

Notes:
- Garder uniquement les dépendances packagées en `*.tgz` dans `premyom-vscode-python/charts/` (ex: `vscode-python-2.4.2.tgz`), ne pas committer une copie extraite du chart (sinon Helm peut utiliser le dossier et casser la résolution des dépendances).
- Même règle pour `premyom-code-server/charts/`.
