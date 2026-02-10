# premyom-s3-explorer

Explorateur de fichiers basé sur Filebrowser, exposant le contenu monté sous `/mnt/s3`.

## Image

- Image: `harbor.lan/premyom/onyxia-s3-explorer:<tag>`
- Sources image: `premyom-s3-explorer/image/`

## SSO

Par défaut ce chart utilise `sso.mode=embedded` (un `oauth2-proxy` dédié par service).

Le callback OIDC est **centralisé** sur :

`https://datalab.arkam-group.com/premyom-oauth2/<release>/callback`

Pour les détails et le debug, voir `SSO.md` à la racine du repo.

