{{- define "premyom-rstudio.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "premyom-rstudio.labels" -}}
app.kubernetes.io/name: premyom-rstudio
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "premyom-rstudio.redirectUrl" -}}
{{- if .Values.sso.redirectUrl -}}
{{- .Values.sso.redirectUrl -}}
{{- else -}}
{{- $scheme := ternary "https" "http" (default false .Values.sso.ingress.tls) -}}
{{- printf "%s://%s/premyom-oauth2/%s/callback" $scheme (include "premyom-rstudio.centralHost" .) .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "premyom-rstudio.centralHost" -}}
{{- default "datalab.arkam-group.com" .Values.sso.centralHost -}}
{{- end -}}

{{- define "premyom-rstudio.cookieDomain" -}}
{{- if .Values.sso.cookieDomain -}}
{{- .Values.sso.cookieDomain -}}
{{- else -}}
{{- .Values.sso.ingress.hostname -}}
{{- end -}}
{{- end -}}

{{- define "premyom-rstudio.whitelistDomain" -}}
{{- if .Values.sso.whitelistDomain -}}
{{- .Values.sso.whitelistDomain -}}
{{- else -}}
{{- .Values.sso.ingress.hostname -}}
{{- end -}}
{{- end -}}
