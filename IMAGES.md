# Images (conventions & nomenclature)

Objectif : garder des noms d’images **compréhensibles**, **prédictibles** et **cohérents** entre :
- le build (VM DockerBuild),
- la registry (Harbor),
- les charts Onyxia (catalogue “Premyom services”).

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
- Dockerfile : `premyom-code-server/image/Dockerfile`
- Entrypoint : `premyom-code-server/image/entrypoint.sh`
- Build scripts : `premyom-code-server/image/build.sh`, `premyom-code-server/image/build_and_push.sh`

Consommation (Onyxia) :
- via le chart `premyom-code-server` (catalogue “Premyom services”)

### `onyxia-s3-explorer` (image)

Rôle :
- explorateur de fichiers (Filebrowser) sur `/mnt/s3`
- mêmes montages S3 (s3fs) basés sur les groupes Keycloak

Repo (Harbor) :
- `harbor.lan/premyom/onyxia-s3-explorer:<tag>`

Repo (DockerHub) (optionnel) :
- `stephanerenouard/onyxia-s3-explorer:<tag>`

Sources :
- Dockerfile : `premyom-s3-explorer/image/Dockerfile`

Consommation (Onyxia) :
- via le chart `premyom-s3-explorer` (catalogue “Premyom services”)

## Points d’attention (important)

- Les **pods** n’ont pas besoin de résoudre `harbor.lan` pour *pull* une image, mais le **nœud** (k3s/containerd) oui.
  - Sans DNS interne, ajouter `harbor.lan` dans `/etc/hosts` de chaque nœud.
- Le certificat TLS Harbor est auto-signé (LAN) :
  - Docker : `ca.crt` dans `/etc/docker/certs.d/harbor.lan:443/`
  - K3s/containerd : config `registries.yaml` (mirror/hosts) à prévoir si nécessaire.

## Montages S3 (groupes Keycloak)

Les images `onyxia-code-server` et `onyxia-s3-explorer` montent les buckets via `s3fs` en se basant sur `ONYXIA_USER_GROUPS`.

### Convention groupes → buckets

- Groupes supportés (le suffixe est optionnel) :
  - `essilor[_ro|_rw]`
  - `hds-essilor[_ro|_rw]`
- Par défaut, si pas de suffixe, on considère **RW** (compatibilité avec des groupes existants).
- Si plusieurs groupes donnent accès au même bucket, **RW gagne sur RO**.

### Hiérarchie (points dans les noms)

Pour rendre l’arborescence lisible, les points `.` dans le nom de bucket sont traduits en dossiers :

- Bucket `essilor.equipe1` → `/mnt/s3/nonhds/essilor/equipe1`
- Bucket `hds-essilor.equipe2` → `/mnt/s3/hds/essilor/equipe2`

### Cas particulier : bucket racine + buckets “dottés”

Si on a **à la fois** :
- un bucket `essilor`
- et des buckets `essilor.team1`, `essilor.team2`, etc.

Alors monter `essilor` sur `/mnt/s3/nonhds/essilor` peut **masquer** les sous-montages
`/mnt/s3/nonhds/essilor/team1`, `/mnt/s3/nonhds/essilor/team2`, … (selon l’ordre de montage et
l’existence des dossiers côté bucket `essilor`).

Pour éviter cette classe de bug, on monte le bucket “racine” sous :

- `essilor` → `/mnt/s3/nonhds/essilor/_bucket`
- `hds-essilor` → `/mnt/s3/hds/essilor/_bucket`

Exemples de groupes :
- `essilor.equipe1_rw`
- `essilor.equipe2_ro`
- `hds-essilor.equipe1_rw`
