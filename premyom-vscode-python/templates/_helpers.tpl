{{/*
Helpers pour le chart premyom-vscode-python
*/}}

{{- define "vscode-python-custom.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vscode-python-custom.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "vscode-python-custom.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

