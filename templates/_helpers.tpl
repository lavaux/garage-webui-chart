{{/*
Expand the name of the chart.
*/}}
{{- define "garage-webui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name, truncated to 63 chars (DNS limit).
*/}}
{{- define "garage-webui.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "garage-webui.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "garage-webui.labels" -}}
helm.sh/chart: {{ include "garage-webui.chart" . }}
{{ include "garage-webui.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "garage-webui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "garage-webui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "garage-webui.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "garage-webui.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the Secret created by the chart for values given inline.
*/}}
{{- define "garage-webui.secretName" -}}
{{- include "garage-webui.fullname" . }}
{{- end }}

{{/*
Key/value pairs the chart must store in its own Secret. Values that come from
an existing Secret are left out. Renders YAML, empty when nothing is needed.
*/}}
{{- define "garage-webui.secretData" -}}
{{- if and .Values.garage.adminToken (not .Values.garage.existingSecret) }}
admin-token: {{ .Values.garage.adminToken | b64enc | quote }}
{{- end }}
{{- if and .Values.auth.legacyUserPass (not .Values.auth.existingSecret) }}
auth-user-pass: {{ .Values.auth.legacyUserPass | b64enc | quote }}
{{- end }}
{{- if and .Values.google.enabled (not .Values.google.existingSecret) }}
google-client-id: {{ .Values.google.clientId | b64enc | quote }}
google-client-secret: {{ .Values.google.clientSecret | b64enc | quote }}
{{- end }}
{{- end }}

{{/*
Probe with the path prefixed by basePath. Takes (dict "probe" .Values.xProbe "basePath" .Values.basePath).
*/}}
{{- define "garage-webui.probe" -}}
{{- $probe := deepCopy .probe }}
{{- if and .basePath $probe.httpGet }}
{{- $_ := set $probe.httpGet "path" (printf "%s%s" .basePath $probe.httpGet.path) }}
{{- end }}
{{- toYaml $probe }}
{{- end }}

{{/*
Fail early on inconsistent values.
*/}}
{{- define "garage-webui.validate" -}}
{{- if .Values.google.enabled }}
{{- if not .Values.google.allowedDomains }}
{{- fail "google.allowedDomains is required when google.enabled is true (the upstream default only admits adnu.edu.ph accounts)" }}
{{- end }}
{{- if and (not .Values.google.existingSecret) (or (not .Values.google.clientId) (not .Values.google.clientSecret)) }}
{{- fail "google.enabled requires google.clientId and google.clientSecret, or google.existingSecret" }}
{{- end }}
{{- end }}
{{- if and .Values.basePath (or (not (hasPrefix "/" .Values.basePath)) (hasSuffix "/" .Values.basePath)) }}
{{- fail "basePath must start with '/' and must not end with '/'" }}
{{- end }}
{{- end }}
