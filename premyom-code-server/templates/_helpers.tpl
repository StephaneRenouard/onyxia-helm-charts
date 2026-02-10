{{- define "premyom-code-server.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "premyom-code-server.labels" -}}
app.kubernetes.io/name: premyom-code-server
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "premyom-code-server.redirectUrl" -}}
{{- if .Values.sso.redirectUrl -}}
{{- .Values.sso.redirectUrl -}}
{{- else -}}
{{- $scheme := ternary "https" "http" (default false .Values.sso.ingress.tls) -}}
{{- printf "%s://%s/premyom-oauth2/%s/callback" $scheme (include "premyom-code-server.centralHost" .) .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "premyom-code-server.centralHost" -}}
{{- default "datalab.arkam-group.com" .Values.sso.centralHost -}}
{{- end -}}

{{- define "premyom-code-server.cookieDomain" -}}
{{- if .Values.sso.cookieDomain -}}
{{- .Values.sso.cookieDomain -}}
{{- else -}}
{{- .Values.sso.ingress.hostname -}}
{{- end -}}
{{- end -}}

{{- define "premyom-code-server.whitelistDomain" -}}
{{- if .Values.sso.whitelistDomain -}}
{{- .Values.sso.whitelistDomain -}}
{{- else -}}
{{- .Values.sso.ingress.hostname -}}
{{- end -}}
{{- end -}}

{{- define "premyom-code-server.cookieName" -}}
{{- printf "_p_cs_%s" (.Release.Name | replace "-" "_" | trunc 40) -}}
{{- end -}}
