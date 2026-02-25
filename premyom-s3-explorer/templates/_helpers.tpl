{{- define "premyom-s3-explorer.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "premyom-s3-explorer.labels" -}}
app.kubernetes.io/name: premyom-s3-explorer
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "premyom-s3-explorer.redirectUrl" -}}
{{- if .Values.sso.redirectUrl -}}
{{- .Values.sso.redirectUrl -}}
{{- else -}}
{{- $scheme := ternary "https" "http" (default false .Values.sso.ingress.tls) -}}
{{- $callbackMode := default "sameHost" .Values.sso.callbackMode -}}
{{- if eq $callbackMode "central" -}}
{{- printf "%s://%s/premyom-oauth2/%s/callback" $scheme (include "premyom-s3-explorer.centralHost" .) .Release.Name -}}
{{- else -}}
{{- printf "%s://%s/oauth2/callback" $scheme .Values.sso.ingress.hostname -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "premyom-s3-explorer.oauth2ProxyPrefix" -}}
{{- $callbackMode := default "sameHost" .Values.sso.callbackMode -}}
{{- if eq $callbackMode "central" -}}
{{- printf "/premyom-oauth2/%s" .Release.Name -}}
{{- else -}}
/oauth2
{{- end -}}
{{- end -}}

{{- define "premyom-s3-explorer.centralHost" -}}
{{- default "datalab.arkam-group.com" .Values.sso.centralHost -}}
{{- end -}}

{{- define "premyom-s3-explorer.cookieDomain" -}}
{{- if .Values.sso.cookieDomain -}}
{{- .Values.sso.cookieDomain -}}
{{- else -}}
{{- .Values.sso.ingress.hostname -}}
{{- end -}}
{{- end -}}

{{- define "premyom-s3-explorer.whitelistDomain" -}}
{{- if .Values.sso.whitelistDomain -}}
{{- .Values.sso.whitelistDomain -}}
{{- else -}}
{{- .Values.sso.ingress.hostname -}}
{{- end -}}
{{- end -}}
