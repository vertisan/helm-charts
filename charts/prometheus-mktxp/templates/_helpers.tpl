{{/*
Expand the name of the chart.
*/}}
{{- define "prometheus-mktxp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "prometheus-mktxp.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "prometheus-mktxp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "prometheus-mktxp.labels" -}}
helm.sh/chart: {{ include "prometheus-mktxp.chart" . }}
{{ include "prometheus-mktxp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "prometheus-mktxp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "prometheus-mktxp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "prometheus-mktxp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "prometheus-mktxp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create Secret name for Router Config
*/}}
{{- define "prometheus-mktxp.config.router.secretName" -}}
{{- default (printf "%s-router-config" (include "prometheus-mktxp.fullname" .)) .Values.config.router.existingSecret }}
{{- end }}

{{/*
Create Secret name for Scrapper Config
*/}}
{{- define "prometheus-mktxp.config.scrapper.secretName" -}}
{{- default (printf "%s-scrapper-config" (include "prometheus-mktxp.fullname" .)) .Values.config.scrapper.existingSecret }}
{{- end }}
