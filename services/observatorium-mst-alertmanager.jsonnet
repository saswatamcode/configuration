{
  apiVersion: 'v1',
  kind: 'Secret',
  metadata: {
    name: 'alertmanager-config',
    annotations: {
      'qontract.recycle': 'true',
    },
  },
  data: {
    'alertmanager.yaml': std.manifestYamlDoc(
      {
        global: {
          resolve_timeout: '5m',
          slack_api_url: '${APPSRE_INTEGRATION_SLACK}',
        },
        receivers: [
          {
            name: 'default',
          },
          {
            name: 'reference-addon-pagerduty-alerts-stage',
            pagerduty_configs: [
              {
                send_resolved: 'true',
                url: '${MTSRE_PD_URL}',
                routing_key: '${MTSRE_ROUTING_KEY}',
                client: 'Redhat PagerDuty Alert Manager',
                client_url: 'https://redhat.pagerduty.com/alerts',
                description: 'rhobs alert message',
                severity: 'warning',
                component: 'MT-SRE',
              },
            ],
          },
          {
            name: 'slack-monitoring-alerts-stage',
            slack_configs: [
              {
                send_resolved: 'true',
                channel: '#team-monitoring-alert-stage',
                username: 'observatorium-alertmanager ({{{ resource.namespace.cluster.name }}})',
                color: '{{ template "slack.default.color" . }}',
                title: '{{ template "slack.default.title" . }}',
                title_link: '{{ template "slack.default.titlelink" . }}',
                text: '{{ template "slack.default.text" . }}',
                fallback: '{{ template "slack.default.fallback" . }}',
                icon_emoji: '{{ template "slack.default.icon_emoji" . }}',
                icon_url: '{{ template "slack.default.icon_url" . }}',
                actions: [
                  {
                    type: 'button',
                    text: 'Runbook :green_book:',
                    url: '{{ (index .Alerts 0).Annotations.runbook }}',
                  },
                  {
                    type: 'button',
                    text: 'Query :mag:',
                    url: '{{ (index .Alerts 0).GeneratorURL }}',
                  },
                  {
                    type: 'button',
                    text: 'Dashboard :grafana:',
                    url: '{{ (index .Alerts 0).Annotations.dashboard }}',
                  },
                  {
                    type: 'button',
                    text: 'Alert Definition :git:',
                    url: '{{ (index .Alerts 0).Annotations.html_url }}',
                  },
                  {
                    type: 'button',
                    text: 'Silence :no_bell:',
                    url: '{{ template "__alert_silence_link" . }}',
                  },
                  {
                    type: 'button',
                    text: '{{ template "slack.default.link_button_text" . }}',
                    url: '{{ .CommonAnnotations.link_url }}',
                  },
                ],
              },
            ],
          },
        ],
        route: {
          group_interval: '5m',
          group_wait: '30s',
          receiver: 'default',
          repeat_interval: '12h',
          routes: [
            {
              match: {
                tenant_id: '0fc2b00e-201b-4c17-b9f2-19d91adc4fd2',
              },
              receiver: 'slack-monitoring-alerts-stage',
            },
            {
              match: {
                tenant_id: 'd17ea8ce-d4c6-42ef-b259-7d10c9227e93',
              },
              receiver: 'reference-addon-pagerduty-alerts-stage',
            },
          ],
        },
        templates: ['*.tmpl'],
      },
    ),
    'slack.tmpl': |||
      {{ define "__alert_silence_link" -}}
      {{ .ExternalURL }}/#/silences/new?filter=%7B
          {{- range .CommonLabels.SortedPairs -}}
              {{- if ne .Name "alertname" -}}
                  {{- .Name }}%3D"{{- .Value -}}"%2C%20
              {{- end -}}
          {{- end -}}
          alertname%3D"{{ .CommonLabels.alertname }}"%7D
      {{- end }}

      {{ define "__alertmanagerURL" }}{{ .ExternalURL }}/#/alerts?receiver={{ .Receiver | urlquery }}{{ end }}
      {{ define "slack.default.titlelink" }}{{ template "__alertmanagerURL" . }}{{ end }}

      {{ define "__single_message_title" }}{{ range .Alerts.Firing }}{{- if .Annotations.message }} {{ .Annotations.message }} {{- end }}{{ end }}{{ range .Alerts.Resolved }}{{- if .Annotations.message }} {{ .Annotations.message }} {{- end }}
      {{ end }}{{ end }}

      {{/* First line of Slack alerts */}}
      {{ define "slack.default.title" -}}Alert: {{ .CommonLabels.alertname }} [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ if or (and (eq (len .Alerts.Firing) 1) (eq (len .Alerts.Resolved) 0)) (and (eq (len .Alerts.Firing) 0) (eq (len .Alerts.Resolved) 1)) }}{{ template "__single_message_title" . }}{{ end }}{{- end }}

      {{ define "slack.default.fallback" }}{{ template "slack.default.title" . }} | {{ template "slack.default.titlelink" . }}{{ end }}

      {{/* Color of Slack attachment (appears as line next to alert )*/}}
      {{ define "slack.default.color" -}}
          {{ if eq .Status "firing" -}}
              {{ if eq .CommonLabels.severity "test" -}}
                  '#808080'
              {{ else if eq .CommonLabels.severity "warning" -}}
                  warning
              {{ else if eq .CommonLabels.severity "medium" -}}
                  warning
              {{- else if eq .CommonLabels.severity "critical" -}}
                  danger
              {{- else -}}
                  '#439FE0'
              {{- end -}}
          {{ else -}}
          good
          {{- end }}
      {{- end }}

      {{/* Emoji to display as user icon (custom emoji supported!) */}}
      {{ define "slack.default.icon_emoji" }}:prometheus:{{ end }}

      {{ define "slack.default.icon_url" }}https://avatars3.githubusercontent.com/u/3380462{{ end }}

      {{/* The text to display in the alert */}}
      {{/* define "slack.default.text" -}}{{ range .Alerts }}{{ if eq .Status "firing" -}}{{- if .Annotations.message }}{{ .Annotations.message }}{{- end }}{{- if .Annotations.description }}{{ .Annotations.description }}{{- end }}{{- end }}{{ if eq .Status "resolved" -}}{{- if .Annotations.message }}Resolved: {{ .Annotations.message }}{{- end }}{{- end }}{{- end }}{{- end */}}

      {{ define "slack.default.text" }}
      {{ if or (and (eq (len .Alerts.Firing) 1) (eq (len .Alerts.Resolved) 0)) (and (eq (len .Alerts.Firing) 0) (eq (len .Alerts.Resolved) 1)) }}
      {{ range .Alerts.Firing }}{{ .Annotations.link_url }}{{ end }}{{ range .Alerts.Resolved }}{{ .Annotations.link_url }}{{ end }}
      {{ range .Alerts.Firing }}{{ .Annotations.description }}{{ end }}{{ range .Alerts.Resolved }}{{ .Annotations.description }}{{ end }}
      {{ else }}
      {{ if gt (len .Alerts.Firing) 0 }}
      *Alerts Firing:*
      {{ range .Alerts.Firing }}- {{- if .Annotations.message }} {{ .Annotations.message }} {{- end }}{{- if .Annotations.link_url }}: {{ .Annotations.link_url }}{{- end }}
      {{ end }}{{ end }}
      {{ if gt (len .Alerts.Resolved) 0 }}
      *Alerts Resolved:*
      {{ range .Alerts.Resolved }}- {{- if .Annotations.message }} {{ .Annotations.message }} {{- end }}{{- if .Annotations.link_url }}: {{ .Annotations.link_url }}{{- end }}
      {{ end }}{{ end }}
      {{ end }}
      {{ end }}

      {{ define "slack.default.link_button_text" -}}
          {{- if .CommonAnnotations.link_text -}}
              {{- .CommonAnnotations.link_text -}}
          {{- else -}}
              Link
          {{- end }} :link:
      {{- end }}
    |||,
  },
}
