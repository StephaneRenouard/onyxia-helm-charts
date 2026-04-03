{{- define "premyom-sofa.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "premyom-sofa.labels" -}}
app.kubernetes.io/name: premyom-sofa
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "premyom-sofa.redirectUrl" -}}
{{- if .Values.sso.redirectUrl -}}
{{- .Values.sso.redirectUrl -}}
{{- else -}}
{{- $scheme := ternary "https" "http" (default false .Values.sso.ingress.tls) -}}
{{- printf "%s://%s/premyom-oauth2/%s/callback" $scheme (include "premyom-sofa.centralHost" .) .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "premyom-sofa.centralHost" -}}
{{- default "datalab.arkam-group.com" .Values.sso.centralHost -}}
{{- end -}}

{{- define "premyom-sofa.cookieDomain" -}}
{{- if .Values.sso.cookieDomain -}}
{{- .Values.sso.cookieDomain -}}
{{- else -}}
{{- .Values.sso.ingress.hostname -}}
{{- end -}}
{{- end -}}

{{- define "premyom-sofa.whitelistDomain" -}}
{{- if .Values.sso.whitelistDomain -}}
{{- .Values.sso.whitelistDomain -}}
{{- else -}}
{{- .Values.sso.ingress.hostname -}}
{{- end -}}
{{- end -}}
