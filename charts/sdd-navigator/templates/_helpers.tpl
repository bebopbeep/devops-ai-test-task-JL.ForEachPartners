{{/* # @req SCI-HELM-006 */}}
{{- define "sdd-navigator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sdd-navigator.namespace" -}}
{{- default .Release.Namespace .Values.global.namespace -}}
{{- end -}}

{{- define "sdd-navigator.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "sdd-navigator.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "sdd-navigator.componentFullname" -}}
{{- printf "%s-%s" .root.Release.Name .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sdd-navigator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sdd-navigator.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "sdd-navigator.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name (.root.Chart.Version | replace "+" "_") }}
{{ include "sdd-navigator.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/version: {{ default .root.Chart.AppVersion .version | quote }}
{{- end -}}

{{- define "sdd-navigator.image" -}}
{{- $registry := trimSuffix "/" .root.Values.global.imageRegistry -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry .image.repository .image.tag -}}
{{- else -}}
{{- printf "%s:%s" .image.repository .image.tag -}}
{{- end -}}
{{- end -}}
