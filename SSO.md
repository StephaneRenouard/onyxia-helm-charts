# SSO (Keycloak) — Premyom services

Ce repo contient des charts Onyxia “wrapper” (`premyom-*`) qui déploient des services exposés en HTTPS via Traefik.

Les services “Premyom” utilisent Keycloak (realm `onyxia`) pour l’authentification.

## Contexte (noms / URLs)

- Onyxia UI: `https://datalab.arkam-group.com`
- Keycloak (realm `onyxia`):
  - Compte utilisateur: `https://auth.datalab.arkam-group.com/auth/realms/onyxia/account`
  - Console admin realm: `https://auth.datalab.arkam-group.com/auth/admin/onyxia/console/`
- Workspaces (services Onyxia): `https://single-project-<id>-0.datalab.arkam-group.com`

## Architecture SSO retenue (mode `embedded`)

Pour chaque service/workspace `premyom-*`, on déploie un **oauth2-proxy dédié** (Deployment + Service) qui reverse-proxy le service applicatif (code-server, filebrowser…).

Le schéma (très simplifié) :

1. L’utilisateur ouvre `https://single-project-<id>-0.../`
2. Traefik route vers `<release>-oauth2-proxy`
3. oauth2-proxy initie le flow OIDC vers Keycloak
4. Keycloak renvoie le navigateur vers **un callback central** :
   - `https://datalab.arkam-group.com/premyom-oauth2/<release>/callback`
5. Traefik route ce callback vers le même `<release>-oauth2-proxy`
6. oauth2-proxy pose le cookie de session puis redirige vers le workspace

## Pourquoi un callback central (et pas sur `single-project-*`) ?

Symptôme : `Invalid parameter: redirect_uri` (Keycloak, HTTP 400).

Cause : Keycloak **n’accepte généralement pas** les wildcards de type `https://*.datalab.arkam-group.com/...` dans les
Redirect URIs (wildcard sur le **host**). Même si ça “ressemble” à ce qui est attendu, la validation échoue, et le flow OIDC
ne démarre pas.

Conclusion : le callback doit rester sur un host “fixe” (`datalab.arkam-group.com`) avec un wildcard sur le **path**.

## Traefik : callback via IngressRoute (et pas Ingress)

Le callback central est routé via une ressource **Traefik CRD** (`IngressRoute`) et non un `Ingress` Kubernetes.

Raison : Onyxia choisit parfois la “mauvaise” URL de service quand plusieurs Ingress existent (ex: ouvrir l’endpoint de callback
au lieu du workspace), ce qui se traduit par des pages `not found`, `Found.`, ou des boucles de redirection côté navigateur.

En pratique :
- `Ingress` Kubernetes = uniquement le host `single-project-...` (le “vrai” service)
- `IngressRoute` = uniquement le callback central `/premyom-oauth2/<release>/...`

## Prérequis Keycloak

Realm: `onyxia`

Client: `oauth2-proxy`

Redirect URI à autoriser (minimum) :
- `https://datalab.arkam-group.com/premyom-oauth2/*`

Notes :
- Le `redirect_uri` envoyé à Keycloak dépend de `--redirect-url` côté oauth2-proxy.
- Les variantes “host wildcard” (`https://*.datalab.arkam-group.com/...`) ne sont **pas** fiables et provoquent `Invalid parameter: redirect_uri`.

## Vérifications rapides (debug)

### 1) Vérifier le `redirect_uri` réellement envoyé à Keycloak

Sur le cluster, récupérer le host du workspace, puis lire l’en-tête `Location` :

```bash
REL=premyom-code-server-XXXXXX
HOST=$(kubectl -n onyxia get ingress ${REL}-ingress -o jsonpath='{.spec.rules[0].host}')
curl -skI "https://${HOST}/" | sed -n '1,20p'
```

On doit voir une redirection vers Keycloak contenant :
`redirect_uri=https%3A%2F%2Fdatalab.arkam-group.com%2Fpremyom-oauth2%2F${REL}%2Fcallback`

Si Keycloak répond `HTTP 400` avec `Invalid parameter: redirect_uri` :
- vérifier que `https://datalab.arkam-group.com/premyom-oauth2/*` est bien présent dans les Redirect URIs du client `oauth2-proxy`
- vérifier que l’IngressRoute callback existe bien côté Traefik

### 2) Interpréter un `403` sur le callback

Un `403` sur :
`https://datalab.arkam-group.com/premyom-oauth2/<release>/callback`
est **normal** si l’URL est appelée “à la main” (curl, navigateur sans cookies oauth2-proxy) :
oauth2-proxy attend un cookie CSRF/état pour terminer le flow.

### 3) Vérifier que le callback est bien routé vers le bon oauth2-proxy

```bash
REL=premyom-code-server-XXXXXX
kubectl -n onyxia get ingress,ingressroute | grep "$REL" || true
```

Attendu :
- `Ingress` : `single-project-...` -> service `<REL>-oauth2-proxy`
- `IngressRoute` : `Host(datalab.arkam-group.com) && PathPrefix(/premyom-oauth2/<REL>)` -> service `<REL>-oauth2-proxy`

### 4) Logs oauth2-proxy

```bash
REL=premyom-code-server-XXXXXX
kubectl -n onyxia logs deploy/${REL}-oauth2-proxy --since=10m | tail -n 200
```

Signaux utiles :
- `Authenticated via OAuth2: Session{...}` => login OK
- `Invalid parameter: redirect_uri` => refus Keycloak (cf. section “Prérequis Keycloak”)

## Ce qui marche / ce qui ne marche pas (historique)

Marche :
- `embedded` avec callback central `datalab.arkam-group.com/premyom-oauth2/<release>/callback`
- callback routé en Traefik `IngressRoute` (évite les “not found” quand Onyxia ouvre le callback)

Ne marche pas (dans ce contexte Keycloak) :
- callback OIDC sur `single-project-.../oauth2/callback` (host wildcard) => `Invalid parameter: redirect_uri`

