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

### Pré-requis kubeconfig (tunnel)

Sur Arkam, le kubeconfig “tunnel” pointe sur `https://127.0.0.1:6443` (kubectl local).  
Si la commande renvoie `connection refused`, le tunnel SSH / port-forward n’est pas actif.

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

## Bug connu (à investiguer) : “1er lancement KO, 2e OK”

Symptôme (Onyxia UI) :
- au **premier clic** sur “Ouvrir le service” après création d’un workspace `premyom-code-server`, le navigateur revient sur la page d’accueil Onyxia (ou une redirection “invisible”),
- le **pod est bien lancé** (Ingress OK),
- en relançant “Ouvrir le service” une seconde fois, l’UI du workspace est accessible.

Statut :
- **non résolu** à ce stade (comportement intermittent).

Hypothèses probables (à confirmer par logs) :
- course condition / timing entre la création du workspace, la disponibilité de l’Ingress, et l’init OIDC,
- cookies oauth2-proxy (CSRF / session) non persistés au premier aller/retour (notamment Safari / politiques anti-tracking),
- redirection initiale vers le callback sans cookie (ce qui est “normal” en direct) puis l’UI Onyxia ré-ouvre l’URL.

Workaround (acceptable en démo, mais pas satisfaisant) :
- relancer “Ouvrir le service” une seconde fois.

### Logs à capturer quand le bug se reproduit

1) Identifier le release le plus récent (ex: `premyom-code-server-343938`) :

```bash
REL="$(kubectl -n onyxia get pods --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | grep -E '^premyom-code-server-[0-9]+-vscode-python-0$' \
  | tail -n 1 \
  | sed 's/-vscode-python-0$//')"
echo "REL=$REL"
```

2) Ingress & callback route :

```bash
kubectl -n onyxia get ingress,ingressroute | grep "$REL" || true
```

3) Logs oauth2-proxy du workspace :

```bash
kubectl -n onyxia logs deploy/${REL}-oauth2-proxy --since=10m | tail -n 200
```

4) Logs Onyxia API (au moment du clic) :

```bash
kubectl -n onyxia logs deploy/onyxia-api --since=10m | tail -n 200
```

## Ce qui marche / ce qui ne marche pas (historique)

Marche :
- `embedded` avec callback central `datalab.arkam-group.com/premyom-oauth2/<release>/callback`
- callback routé en Traefik `IngressRoute` (évite les “not found” quand Onyxia ouvre le callback)

Ne marche pas (dans ce contexte Keycloak) :
- callback OIDC sur `single-project-.../oauth2/callback` (host wildcard) => `Invalid parameter: redirect_uri`
