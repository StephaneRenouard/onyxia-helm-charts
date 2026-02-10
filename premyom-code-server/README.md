# premyom-code-server

Workspace code-server “Premyom” pour Onyxia.

## Image

- Image: `harbor.lan/premyom/onyxia-code-server:<tag>`
- Sources image: `premyom-code-server/image/`

## SSO

Par défaut ce chart utilise `sso.mode=embedded` (un `oauth2-proxy` dédié par workspace).

Le callback OIDC est **centralisé** sur :

`https://datalab.arkam-group.com/premyom-oauth2/<release>/callback`

Raison : Keycloak n’accepte pas de façon fiable un wildcard sur le host (ex: `https://*.datalab.../oauth2/callback`), ce qui
provoque `Invalid parameter: redirect_uri`.

Pour les détails et le debug, voir `SSO.md` à la racine du repo.

