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
{{- printf "%s://%s/oauth2/callback" $scheme .Values.sso.ingress.hostname -}}
{{- end -}}
{{- end -}}
