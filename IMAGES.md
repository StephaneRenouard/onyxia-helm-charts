# Images (conventions & nomenclature)

Objectif : garder des noms d’images **compréhensibles**, **prédictibles** et **cohérents** entre :
- le build (VM DockerBuild),
- la registry (Harbor),
- les charts Onyxia (catalogue “Premyom Workspaces”).

## Convention de nommage

Format recommandé :

`<registry>/<projet>/<image>:<version>`

Exemple (Harbor local) :

`harbor.lan/premyom/onyxia-code-server:0.1.3`

Règles :
- `registry` : hostname Harbor (ex: `harbor.lan`)
- `projet` : projet Harbor (ex: `premyom`)
- `image` : nom simple, kebab-case (ex: `onyxia-code-server`)
- `version` : SemVer (ex: `0.1.3`)

## Images actuelles

### `onyxia-code-server` (image)

Rôle :
- image “IDE” indépendante (base Debian) avec `code-server` + `/opt/onyxia-init.sh`
- compat Onyxia : `/opt/onyxia-init.sh`, port `8080`

Repo (Harbor) :
- `harbor.lan/premyom/onyxia-code-server:<tag>`

Repo (DockerHub) :
- `stephanerenouard/onyxia-code-server:<tag>`

Sources :
- Dockerfile : `base/code-server.dockerfile`
- Entrypoint : `base/entrypoint.sh`
- Build scripts : `base/build.sh`, `base/build_and_push.sh`

Consommation (Onyxia) :
- via le chart `premyom-code-server` (catalogue “Premyom Workspaces”)

## Points d’attention (important)

- Les **pods** n’ont pas besoin de résoudre `harbor.lan` pour *pull* une image, mais le **nœud** (k3s/containerd) oui.
  - Sans DNS interne, ajouter `harbor.lan` dans `/etc/hosts` de chaque nœud.
- Le certificat TLS Harbor est auto-signé (LAN) :
  - Docker : `ca.crt` dans `/etc/docker/certs.d/harbor.lan:443/`
  - K3s/containerd : config `registries.yaml` (mirror/hosts) à prévoir si nécessaire.
