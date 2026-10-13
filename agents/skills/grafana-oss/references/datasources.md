# Grafana Data Sources - Detailed Reference

## Overview

Data sources are connections between Grafana and the systems storing your data. Grafana ships with built-in support for many popular data sources and supports additional sources via plugins.

- Only **Organization Admins** can add or remove data sources
- Each data source has its own query editor
- Data sources can be used in: Dashboard panels, Explore, Alert rules, Annotations

______________________________________________________________________

## Managing Data Sources

### Add a data source

1. Go to **Connections > Data sources** (or **Configuration > Data sources** in older versions)
1. Click **Add new data source**
1. Search for and select the data source type
1. Fill in connection details (URL, credentials, etc.)
1. Click **Save & Test** to verify the connection

### Data source settings (common to all types)

| Setting | Description |
|---------|-------------|
| Name | Display name used in dashboards |
| Default | If checked, pre-selected in new panels |
| HTTP URL | The endpoint for the data source server |
| Auth | Basic auth, TLS, bearer token, API key options |

______________________________________________________________________

## Prometheus

Native support - no plugin required.

### Configuration

```ini
URL: http://prometheus:9090
HTTP method: POST (recommended, supports longer queries)
```

### Key options

| Option | Description |
|--------|-------------|
| Scrape interval | Default: 15s - should match your Prometheus scrape interval |
| Query timeout | Default: 60s |
| Exemplars | Enable to link metrics to traces |
| Ruler URL | For Prometheus-managed alert rules |

### Query editor

- **Metrics browser**: Browse available metrics with autocomplete
- **Query type**: Range query (time series) or Instant query (single value)
- **Legend**: Customize series labels using `{{label_name}}` syntax

### Template variables with Prometheus

```
# Variable type: Query
# Query examples:
label_values(metric_name, label_name)    # All values of a label for a metric
label_values(label_name)                  # All values across all metrics
metrics(prefix)                           # All metric names matching prefix
query_result(promql_expression)           # PromQL result as variable values
```

### Exemplars

When enabled, Prometheus exemplars link high-cardinality trace IDs to metric data points. Requires a Tempo data source for trace drill-through.

______________________________________________________________________

## Loki (Log Aggregation)

### Configuration

```ini
URL: http://loki:3100
Maximum lines: 1000
```

### Derived fields

Extract values from log lines and link to other systems.

Example - extract trace ID and link to Tempo:

```
Name: TraceID
Regex: traceID=(\w+)
URL: (internal link to Tempo data source)
```

### Query editor (LogQL)

```logql
# Basic log stream selector
{job="nginx", namespace="production"}

# Filter by text
{job="nginx"} |= "error"
{job="nginx"} != "debug"

# Regex filter
{job="nginx"} |~ "status=5\d\d"

# Parse and filter structured logs
{job="api"} | json | level="error"
{job="api"} | logfmt | duration > 1s

# Metrics from logs
rate({job="nginx"} |= "error" [5m])
sum(rate({job="nginx"}[5m])) by (status_code)
```

### Template variables with Loki

```
label_names()                          # All label names
label_values(label_name)               # All values for a label
label_values({job="nginx"}, pod)       # Label values filtered by stream selector
```

______________________________________________________________________

## Tempo (Distributed Tracing)

### Configuration

```ini
URL: http://tempo:3200
```

### Key options

| Option | Description |
|--------|-------------|
| Trace to logs | Link traces to Loki logs via trace ID |
| Trace to metrics | Link trace spans to Prometheus metrics |
| Service graph | Enable service dependency graph |
| Node graph | Show trace as node graph |

### TraceQL (query language)

```traceql
# Find traces with error spans
{status=error}

# Filter by service and duration
{.service.name="frontend" && duration > 1s}

# Structural queries
{.http.url=~"/api/.*"} >> {status=error}
```

______________________________________________________________________

## Alertmanager

For connecting to an external Alertmanager.

```ini
URL: http://alertmanager:9093
# Implementation: Prometheus, Mimir, or Cortex
```

______________________________________________________________________

## Elasticsearch / OpenSearch

### Configuration

```ini
URL: http://elasticsearch:9200
Index name: logs-*
Time field name: @timestamp
Elasticsearch version: 8.x
```

______________________________________________________________________

## MySQL

Built-in support for MySQL 5.7+ and compatible databases (MariaDB, Percona, Amazon Aurora MySQL, Azure Database for MySQL, Google Cloud SQL MySQL).

### Configuration

```ini
Host: mysql:3306
Database: mydb
User: grafana
Password: secret
Max open connections: 100
Max idle connections: 100
Connection max lifetime: 14400
```

### Time series queries

```sql
SELECT
  UNIX_TIMESTAMP(time_col) as time_sec,
  value_col as value,
  name_col as metric
FROM my_table
WHERE $__timeFilter(time_col)
ORDER BY time_col ASC
```

### Macros

| Macro | Description |
|-------|-------------|
| `$__time(column)` | Converts column to Unix timestamp |
| `$__timeFilter(column)` | Adds WHERE clause for dashboard time range |
| `$__timeFrom()` | Start of dashboard time range as Unix timestamp |
| `$__timeTo()` | End of dashboard time range as Unix timestamp |
| `$__timeGroup(column, interval)` | Groups by time interval |
| `$__timeGroupAlias(column, interval)` | As above, aliases as "time" |
| `$__unixEpochFilter(column)` | Time filter for Unix epoch columns |
| `$__interval` | Auto-calculated interval for current time range |

### Example time series query

```sql
SELECT
  $__timeGroup(created_at, $__interval) AS time,
  status,
  count(*) AS cnt
FROM orders
WHERE $__timeFilter(created_at)
GROUP BY 1, 2
ORDER BY 1
```

### Annotations

```sql
SELECT
  UNIX_TIMESTAMP(time) AS time,
  title AS text,
  tags
FROM events
WHERE $__timeFilter(time)
```

______________________________________________________________________

## PostgreSQL

### Configuration

```ini
Host: postgres:5432
Database: mydb
User: grafana
Password: secret
SSL mode: disable / require / verify-ca / verify-full
```

### PostgreSQL time series

```sql
SELECT
  time_bucket('$__interval', time) AS time,
  avg(value)
FROM metrics
WHERE time BETWEEN $__timeFrom() AND $__timeTo()
GROUP BY 1
ORDER BY 1
```

______________________________________________________________________

## Microsoft SQL Server

### Configuration

```ini
Host: sqlserver:1433
Database: mydb
User: grafana
Password: secret
Encrypt: false / true / disable
```

______________________________________________________________________

## InfluxDB

Supports InfluxDB 1.x (InfluxQL) and InfluxDB 2.x / 3.x (Flux).

### InfluxDB 1.x (InfluxQL)

```ini
URL: http://influxdb:8086
Database: telegraf
```

Query example:

```sql
SELECT mean("value") FROM "measurement"
WHERE $timeFilter
GROUP BY time($interval), "host"
```

### InfluxDB 2.x (Flux)

```ini
URL: http://influxdb:8086
Organization: myorg
Token: <api-token>
Default bucket: mydata
```

Flux query example:

```flux
from(bucket: "mydata")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "cpu")
  |> filter(fn: (r) => r._field == "usage_idle")
  |> aggregateWindow(every: v.windowPeriod, fn: mean)
```

______________________________________________________________________

## AWS CloudWatch

### Configuration

```ini
# Auth options:
# - AWS SDK Default (instance role, ~/.aws/credentials, env vars)
# - Access & secret key (explicit credentials)
# - Assume role ARN

Default region: us-east-1
```

Required IAM permissions:

- `cloudwatch:GetMetricData`
- `cloudwatch:ListMetrics`
- `logs:*` (for CloudWatch Logs)

### CloudWatch Logs Insights

```
fields @timestamp, @message
| filter level = "ERROR"
| sort @timestamp desc
| limit 100
```

______________________________________________________________________

## Azure Monitor

Requires Azure App Registration with:

- Tenant ID, Client ID, Client Secret
- `Monitoring Reader` role on target subscriptions/resource groups

______________________________________________________________________

## Google Cloud Monitoring

Uses Google Cloud service account credentials (JSON key file or workload identity).

______________________________________________________________________

## TestData (built-in)

A built-in data source for generating test/demo data without a real backend.

Use cases: Testing visualizations, demo dashboards, development without a real data source.
Scenarios: Random walk, CSV metric values, streaming data, etc.

______________________________________________________________________

## Graphite

```ini
URL: http://graphite:8080
```

Query examples:

```
target(servers.*.cpu)
averageSeries(servers.*.cpu)
groupByNode(servers.*.cpu, 1, 'averageSeries')
```

______________________________________________________________________

## Jaeger (Tracing)

```ini
URL: http://jaeger:16686
```

______________________________________________________________________

## Zipkin (Tracing)

```ini
URL: http://zipkin:9411
```

______________________________________________________________________

## Pyroscope (Continuous Profiling)

```ini
URL: http://pyroscope:4040
```

______________________________________________________________________

## Data Source Permissions (Enterprise)

By default, all org users can query any data source. With RBAC:

- Assign specific users/teams to specific data sources
- Configure at **Data source settings > Permissions**

______________________________________________________________________

## Provisioning Data Sources (as Code)

```yaml
# /etc/grafana/provisioning/datasources/prometheus.yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    version: 1
    editable: false
    jsonData:
      timeInterval: "15s"
      queryTimeout: "60s"
      httpMethod: POST

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    jsonData:
      maxLines: 1000
      derivedFields:
        - datasourceUid: tempo
          matcherRegex: "traceID=(\\w+)"
          name: TraceID
          url: "${__value.raw}"

  - name: MySQL Production
    type: mysql
    url: mysql:3306
    database: mydb
    user: grafana
    secureJsonData:
      password: "$GRAFANA_MYSQL_PASSWORD"
    jsonData:
      maxOpenConns: 100
      maxIdleConns: 100
      connMaxLifetime: 14400
```

Place YAML files in the provisioning directory; Grafana loads on startup and watches for changes.

______________________________________________________________________

## Plugin Data Sources

Install additional data sources via:

- **Connections > Add new connection** (search the plugin catalog)
- `grafana-cli plugins install <plugin-id>`
- Docker: set `GF_INSTALL_PLUGINS` environment variable

Popular plugin data sources:

- `grafana-opensearch-datasource` - OpenSearch
- `grafana-bigquery-datasource` - Google BigQuery
- `grafana-mongodb-datasource` - MongoDB (Enterprise)
- `grafana-splunk-datasource` - Splunk
- `grafana-datadog-datasource` - Datadog
