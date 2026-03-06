---
layout: post
title: "Monitoring Java Applications: From JVM Metrics to Production Dashboards"
date: 2026-03-03 10:00 +0100
categories: [Java, DevOps]
tags: [java, monitoring, micrometer, prometheus, grafana, spring-boot, actuator, opentelemetry, jmx, observability]
description: A practical guide to monitoring Java applications covering JVM internals, JMX, Micrometer, Spring Boot Actuator, Prometheus and Grafana integration, OpenTelemetry, custom metrics, health checks, structured logging, and production alerting strategies.
---

# Monitoring Java Applications: From JVM Metrics to Production Dashboards

An application that works on your laptop is not the same as an application that works in production. The difference is observability. When something goes wrong at two in the morning, you need to know what happened, where it happened, and why, without attaching a debugger to a live server.

Monitoring is not a single tool or library. It is a discipline that combines **metrics**, **logs**, and **traces** into a coherent picture of system health. Java has a rich ecosystem for all three, from the JVM's built-in instrumentation to modern frameworks like Micrometer and OpenTelemetry. This guide walks through the entire stack, from raw JVM metrics to production-ready dashboards with alerting.

## The Three Pillars of Observability

Before diving into tools, it helps to understand the three complementary signals that make a system observable.

| Pillar | What It Captures | Example |
|---|---|---|
| **Metrics** | Numeric measurements over time | Request rate, error count, heap usage |
| **Logs** | Discrete events with context | `ERROR OrderService - Payment failed for order 4821` |
| **Traces** | Request flow across services | HTTP call → service A → database → service B → response |

Metrics tell you *something is wrong*. Logs tell you *what went wrong*. Traces tell you *where in the call chain* it went wrong. A good monitoring setup covers all three.

## JVM Metrics: What the Runtime Already Knows

The JVM collects a wealth of information about its own operation. Understanding these metrics is the foundation of Java monitoring, regardless of which tools you use.

### Memory

The JVM divides memory into regions, each with its own behavior and failure mode.

```
┌──────────────────────────────────────────────┐
│                  JVM Process                 │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │              Heap                    │    │
│  │  ┌──────────┐  ┌──────────────────┐  │    │
│  │  │  Young   │  │      Old         │  │    │
│  │  │  Gen     │  │      Gen         │  │    │
│  │  └──────────┘  └──────────────────┘  │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌──────────────┐  ┌──────────────────┐      │
│  │  Metaspace   │  │  Thread Stacks   │      │
│  └──────────────┘  └──────────────────┘      │
│                                              │
│  ┌──────────────┐  ┌──────────────────┐      │
│  │ Code Cache   │  │ Direct Buffers   │      │
│  └──────────────┘  └──────────────────┘      │
└──────────────────────────────────────────────┘
```

| Metric | Why It Matters |
|---|---|
| **Heap used / committed / max** | A steadily rising heap that never decreases after GC suggests a memory leak |
| **GC pause duration** | Long pauses cause latency spikes visible to users |
| **GC frequency** | Frequent young-gen collections under light load indicate undersized heap or excessive allocation |
| **Metaspace used** | Growth without bound often means classloader leaks, common in application servers with hot redeploy |
| **Direct buffer usage** | NIO-heavy applications can exhaust off-heap memory without touching the heap |

### Threads

| Metric | Why It Matters |
|---|---|
| **Thread count** | An ever-growing thread count points to a pool misconfiguration or leaked threads |
| **Blocked / waiting threads** | High counts indicate contention or deadlocks |
| **Thread pool active vs. queue size** | Saturated pools cause request rejection |

### Garbage Collection

Different GC algorithms have different characteristics, but the metrics you watch are the same.

| GC Algorithm | Typical Use Case | Key Metric to Watch |
|---|---|---|
| **G1GC** | General purpose (default since Java 9) | Pause duration, humongous allocations |
| **ZGC** | Ultra-low latency | Allocation stalls, relocation volume |
| **Shenandoah** | Low latency (Red Hat) | Concurrent GC time, pacing delays |
| **Serial / Parallel** | Small heaps or batch jobs | Total pause time |

## JMX: The JVM's Built-In Monitoring API

**Java Management Extensions (JMX)** is the standard API for exposing and reading management data from a JVM. Every metric discussed above is available through JMX MBeans without adding any dependency.

### Enabling Remote JMX

Add these JVM arguments to expose JMX over RMI:

```bash
java -Dcom.sun.management.jmxremote \
     -Dcom.sun.management.jmxremote.port=9010 \
     -Dcom.sun.management.jmxremote.rmi.port=9010 \
     -Dcom.sun.management.jmxremote.authenticate=false \
     -Dcom.sun.management.jmxremote.ssl=false \
     -jar app.jar
```

> **Security warning:** The example above disables authentication and SSL for simplicity. In production, always enable both or tunnel JMX over SSH.

### Reading MBeans Programmatically

```java
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.lang.management.MemoryUsage;
import java.lang.management.ThreadMXBean;
import java.lang.management.GarbageCollectorMXBean;

public class JmxMonitor {

    public static void main(String[] args) {
        MemoryMXBean memory = ManagementFactory.getMemoryMXBean();
        MemoryUsage heap = memory.getHeapMemoryUsage();

        System.out.printf("Heap used: %d MB%n", heap.getUsed() / (1024 * 1024));
        System.out.printf("Heap max:  %d MB%n", heap.getMax() / (1024 * 1024));

        ThreadMXBean threads = ManagementFactory.getThreadMXBean();
        System.out.printf("Live threads: %d%n", threads.getThreadCount());
        System.out.printf("Deadlocked:   %s%n",
                threads.findDeadlockedThreads() != null ? "YES" : "no");

        for (GarbageCollectorMXBean gc :
                ManagementFactory.getGarbageCollectorMXBeans()) {
            System.out.printf("GC [%s]: %d collections, %d ms total%n",
                    gc.getName(), gc.getCollectionCount(),
                    gc.getCollectionTime());
        }
    }
}
```

### Exposing Custom MBeans

You can expose application-specific data through JMX by defining an MBean interface.

```java
public interface OrderServiceMBean {
    long getOrdersProcessed();
    long getOrdersFailed();
    double getAverageProcessingTimeMs();
}
```

```java
import java.lang.management.ManagementFactory;
import javax.management.ObjectName;

public class OrderService implements OrderServiceMBean {

    private long ordersProcessed;
    private long ordersFailed;
    private double averageProcessingTimeMs;

    // Business methods that update the counters ...

    @Override
    public long getOrdersProcessed() { return ordersProcessed; }

    @Override
    public long getOrdersFailed() { return ordersFailed; }

    @Override
    public double getAverageProcessingTimeMs() { return averageProcessingTimeMs; }

    public void register() throws Exception {
        ObjectName name = new ObjectName("com.example:type=OrderService");
        ManagementFactory.getPlatformMBeanServer().registerMBean(this, name);
    }
}
```

JMX is powerful but low-level. Modern applications typically use it as a data source behind a higher-level metrics facade.

## Micrometer: The Metrics Facade for Modern Java

**Micrometer** is to metrics what SLF4J is to logging: a vendor-neutral facade that lets you instrument your code once and ship metrics to any backend.

### Supported Backends

| Backend | Protocol | Use Case |
|---|---|---|
| Prometheus | Pull (scrape) | Most popular open-source monitoring stack |
| Datadog | Push (API) | Managed SaaS observability |
| New Relic | Push (API) | APM-focused SaaS |
| InfluxDB | Push (line protocol) | Time-series database |
| CloudWatch | Push (AWS API) | AWS-native monitoring |
| Graphite | Push (plaintext) | Legacy but still common |
| OTLP | Push (gRPC/HTTP) | OpenTelemetry Collector |

### Adding Micrometer to a Project

For a Spring Boot application, add the starter and the registry for your backend.

```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-core</artifactId>
</dependency>

<!-- Prometheus registry -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

For a non-Spring application, create a registry manually:

```java
import io.micrometer.prometheusmetrics.PrometheusConfig;
import io.micrometer.prometheusmetrics.PrometheusMeterRegistry;

PrometheusMeterRegistry registry =
        new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);
```

### Metric Types

Micrometer provides several instrument types, each suited to a different kind of measurement.

#### Counter

Tracks a value that only goes up: requests served, errors encountered, bytes sent.

```java
Counter orderCounter = Counter.builder("orders.created")
        .description("Total orders created")
        .tag("region", "eu-west")
        .register(registry);

orderCounter.increment();
```

#### Gauge

Tracks a value that can go up or down: queue depth, active connections, cache size.

```java
List<Order> pendingOrders = new ArrayList<>();

Gauge.builder("orders.pending", pendingOrders, List::size)
        .description("Orders waiting for processing")
        .register(registry);
```

#### Timer

Measures the duration of short operations and tracks the count of invocations.

```java
Timer timer = Timer.builder("orders.processing.duration")
        .description("Time to process an order")
        .publishPercentiles(0.5, 0.95, 0.99)
        .register(registry);

timer.record(() -> processOrder(order));
```

#### Distribution Summary

Like a timer but for non-time values: request payload sizes, batch sizes, result set rows.

```java
DistributionSummary summary = DistributionSummary
        .builder("http.response.size")
        .description("Response payload size in bytes")
        .baseUnit("bytes")
        .publishPercentileHistogram()
        .register(registry);

summary.record(responseBody.length);
```

### Tagging Best Practices

Tags (also called labels) add dimensions to metrics. They are powerful but require discipline.

| Do | Don't |
|---|---|
| Use bounded tag values: `status=200`, `status=404` | Use unbounded values: `userId=83291` |
| Keep cardinality under a few hundred per metric | Create millions of time series by accident |
| Use consistent naming: `snake_case` or `dot.separated` | Mix naming conventions across the codebase |
| Tag with business-relevant dimensions: `region`, `payment_method` | Tag with debugging info that belongs in logs |

High cardinality is the number-one cause of monitoring system performance problems. A metric with a `userId` tag creates a separate time series for every user, which can overwhelm Prometheus and Grafana.

## Spring Boot Actuator: Production-Ready Endpoints

Spring Boot Actuator exposes operational information through HTTP endpoints and integrates directly with Micrometer.

### Setup

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics, prometheus
  endpoint:
    health:
      show-details: when-authorized
  metrics:
    tags:
      application: ${spring.application.name}
```

### Key Endpoints

| Endpoint | Purpose |
|---|---|
| `/actuator/health` | Application health status with component details |
| `/actuator/metrics` | Lists all available metric names |
| `/actuator/metrics/{name}` | Detailed view of a specific metric |
| `/actuator/prometheus` | All metrics in Prometheus exposition format |
| `/actuator/info` | Build info, git commit, custom properties |
| `/actuator/env` | Environment properties (secure by default) |
| `/actuator/loggers` | View and change log levels at runtime |

### Custom Health Indicators

Health checks verify that critical dependencies are reachable and functioning.

```java
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

@Component
public class PaymentGatewayHealthIndicator implements HealthIndicator {

    private final PaymentGatewayClient client;

    public PaymentGatewayHealthIndicator(PaymentGatewayClient client) {
        this.client = client;
    }

    @Override
    public Health health() {
        try {
            client.ping();
            return Health.up()
                    .withDetail("provider", "stripe")
                    .build();
        } catch (Exception e) {
            return Health.down(e)
                    .withDetail("provider", "stripe")
                    .build();
        }
    }
}
```

The `/actuator/health` response now includes:

```json
{
  "status": "UP",
  "components": {
    "db": { "status": "UP" },
    "diskSpace": { "status": "UP" },
    "paymentGateway": {
      "status": "UP",
      "details": { "provider": "stripe" }
    }
  }
}
```

### Security

Actuator endpoints can expose sensitive information. Always secure them in production.

```yaml
management:
  server:
    port: 8081  # Separate port, not exposed to the internet
  endpoints:
    web:
      exposure:
        include: health, prometheus
```

Alternatively, use Spring Security to require authentication:

```java
@Configuration
public class ActuatorSecurityConfig {

    @Bean
    public SecurityFilterChain actuatorSecurity(HttpSecurity http) throws Exception {
        return http
                .securityMatcher("/actuator/**")
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/actuator/health").permitAll()
                        .anyRequest().hasRole("MONITORING"))
                .httpBasic(Customizer.withDefaults())
                .build();
    }
}
```

## Prometheus and Grafana: The Monitoring Stack

Prometheus is a time-series database that scrapes metrics endpoints at regular intervals. Grafana provides visualization and alerting on top of Prometheus data.

### Architecture

```
┌──────────────┐     scrape      ┌──────────────┐     query     ┌──────────────┐
│  Spring Boot │ ◀──────────────│  Prometheus   │◀─────────────│   Grafana    │
│  /actuator/  │    every 15s   │              │              │              │
│  prometheus  │                │  TSDB        │              │  Dashboards  │
└──────────────┘                └──────────────┘              │  Alerts      │
                                       ▲                      └──────────────┘
                                       │ scrape
                                ┌──────────────┐
                                │  Other       │
                                │  Targets     │
                                └──────────────┘
```

### Docker Compose Setup

```yaml
services:
  app:
    build: .
    ports:
      - "8080:8080"
      - "8081:8081"  # Actuator on separate port

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: changeme
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  grafana-data:
```

### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "spring-app"
    metrics_path: "/actuator/prometheus"
    static_configs:
      - targets: ["app:8081"]
    scrape_interval: 10s
```

### Essential PromQL Queries

PromQL is the query language for Prometheus. These queries form the basis of most Java application dashboards.

| What You Want | PromQL |
|---|---|
| Request rate (per second) | `rate(http_server_requests_seconds_count[5m])` |
| 95th percentile latency | `histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))` |
| Error rate | `rate(http_server_requests_seconds_count{status=~"5.."}[5m])` |
| Heap usage percentage | `jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}` |
| GC pause rate | `rate(jvm_gc_pause_seconds_sum[5m])` |
| Active threads | `jvm_threads_live_threads` |
| CPU usage | `process_cpu_usage` |

### Grafana Dashboard

Rather than building dashboards from scratch, import community dashboards and customize them.

| Dashboard ID | Name | What It Shows |
|---|---|---|
| **4701** | JVM (Micrometer) | Heap, GC, threads, CPU, classloading |
| **11378** | Spring Boot Statistics | Request rates, response times, error rates |
| **6756** | Spring Boot Observability | Combined metrics, logs, traces |

Import a dashboard in Grafana: **Dashboards → Import → Enter ID → Select Prometheus data source → Import**.

## OpenTelemetry: Unified Observability

**OpenTelemetry (OTel)** is a CNCF project that provides a single set of APIs, SDKs, and tools for metrics, logs, and traces. It is the emerging standard for observability instrumentation.

### Java Agent (Zero-Code Instrumentation)

The easiest way to adopt OpenTelemetry is the Java agent, which automatically instruments popular libraries.

```bash
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.service.name=order-service \
     -Dotel.exporter.otlp.endpoint=http://otel-collector:4317 \
     -Dotel.metrics.exporter=otlp \
     -Dotel.traces.exporter=otlp \
     -Dotel.logs.exporter=otlp \
     -jar app.jar
```

The agent instruments these libraries automatically (among many others):

| Library | What Is Captured |
|---|---|
| Spring MVC / WebFlux | HTTP server spans and metrics |
| RestTemplate / WebClient | HTTP client spans |
| JDBC | Database query spans with SQL |
| Hibernate | ORM operation spans |
| Kafka, RabbitMQ | Messaging spans with context propagation |
| Logback, Log4j2 | Log correlation with trace IDs |

### Manual Instrumentation

When you need custom spans or metrics beyond what the agent provides:

```java
import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.Tracer;

public class PaymentService {

    private static final Tracer tracer =
            GlobalOpenTelemetry.getTracer("com.example.payment");

    public PaymentResult processPayment(PaymentRequest request) {
        Span span = tracer.spanBuilder("process-payment")
                .setAttribute("payment.method", request.getMethod())
                .setAttribute("payment.currency", request.getCurrency())
                .startSpan();

        try (var scope = span.makeCurrent()) {
            PaymentResult result = gateway.charge(request);
            span.setAttribute("payment.status", result.getStatus());
            return result;
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(io.opentelemetry.api.trace.StatusCode.ERROR);
            throw e;
        } finally {
            span.end();
        }
    }
}
```

### OpenTelemetry Collector

The Collector acts as a pipeline between your application and your observability backends. It can receive, process, and export telemetry data.

```yaml
# otel-collector-config.yml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 5s
    send_batch_size: 1024

exporters:
  prometheus:
    endpoint: 0.0.0.0:8889
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true

service:
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/jaeger]
```

This setup sends metrics to Prometheus and traces to Jaeger, giving you the best of both worlds.

## Structured Logging with Trace Correlation

Logs become far more useful when they are structured (JSON) and correlated with trace IDs.

### Logback Configuration for JSON Output

```xml
<!-- logback-spring.xml -->
<configuration>
    <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeMdcKeyName>traceId</includeMdcKeyName>
            <includeMdcKeyName>spanId</includeMdcKeyName>
        </encoder>
    </appender>

    <root level="INFO">
        <appender-ref ref="JSON" />
    </root>
</configuration>
```

With the OpenTelemetry agent or Micrometer Tracing, trace and span IDs are automatically placed in the MDC. Every log line now carries correlation data:

```json
{
  "timestamp": "2026-03-03T14:22:01.332Z",
  "level": "ERROR",
  "logger": "com.example.OrderService",
  "message": "Payment failed for order 4821",
  "traceId": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6",
  "spanId": "1a2b3c4d5e6f7a8b",
  "orderId": 4821,
  "exception": "com.example.PaymentDeclinedException: Insufficient funds"
}
```

You can now click a trace ID in Grafana to jump from a log line to the full distributed trace.

### Adding Business Context to Logs

Use MDC to attach business-relevant context that persists across a request.

```java
import org.slf4j.MDC;

public class RequestContextFilter implements Filter {

    @Override
    public void doFilter(ServletRequest req, ServletResponse res,
                         FilterChain chain) throws IOException, ServletException {
        HttpServletRequest request = (HttpServletRequest) req;
        try {
            MDC.put("userId", extractUserId(request));
            MDC.put("requestId", UUID.randomUUID().toString());
            chain.doFilter(req, res);
        } finally {
            MDC.clear();
        }
    }
}
```

## Alerting Strategies

Metrics and dashboards are only useful if someone looks at them. Alerting bridges the gap.

### The Four Golden Signals

Google's Site Reliability Engineering book defines four signals that apply to every service.

| Signal | What to Measure | Example Alert |
|---|---|---|
| **Latency** | Duration of successful requests | p99 latency > 500ms for 5 minutes |
| **Traffic** | Demand on the system | Request rate drops > 50% vs. last week |
| **Errors** | Rate of failed requests | Error rate > 1% for 5 minutes |
| **Saturation** | How full the system is | Heap usage > 85% for 10 minutes |

### Prometheus Alerting Rules

```yaml
# alert-rules.yml
groups:
  - name: java-application
    rules:
      - alert: HighErrorRate
        expr: |
          rate(http_server_requests_seconds_count{status=~"5.."}[5m])
          / rate(http_server_requests_seconds_count[5m]) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on {{ $labels.instance }}"
          description: "Error rate is {{ $value | humanizePercentage }}"

      - alert: HighHeapUsage
        expr: |
          jvm_memory_used_bytes{area="heap"}
          / jvm_memory_max_bytes{area="heap"} > 0.85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Heap usage above 85% on {{ $labels.instance }}"

      - alert: HighGcPauseRate
        expr: rate(jvm_gc_pause_seconds_sum[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "GC consuming >10% of time on {{ $labels.instance }}"

      - alert: TooManyBlockedThreads
        expr: jvm_threads_states_threads{state="blocked"} > 20
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "{{ $value }} blocked threads on {{ $labels.instance }}"
```

### Alert Routing with Alertmanager

```yaml
# alertmanager.yml
route:
  receiver: default
  group_by: [alertname, instance]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    - match:
        severity: critical
      receiver: pagerduty

    - match:
        severity: warning
      receiver: slack

receivers:
  - name: default
    email_configs:
      - to: team@example.com

  - name: pagerduty
    pagerduty_configs:
      - service_key: "<key>"

  - name: slack
    slack_configs:
      - api_url: "https://hooks.slack.com/services/T.../B.../..."
        channel: "#alerts"
```

## Putting It All Together: A Complete Example

Here is a minimal but complete Spring Boot application with metrics, health checks, and Prometheus export.

### Dependencies

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>
</dependencies>
```

### Application Configuration

```yaml
# application.yml
spring:
  application:
    name: order-service

management:
  server:
    port: 8081
  endpoints:
    web:
      exposure:
        include: health, info, prometheus, metrics
  metrics:
    distribution:
      percentiles-histogram:
        http.server.requests: true
    tags:
      application: ${spring.application.name}
```

### Instrumented Service

```java
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.stereotype.Service;

@Service
public class OrderService {

    private final Counter createdCounter;
    private final Counter failedCounter;
    private final Timer processingTimer;

    public OrderService(MeterRegistry registry) {
        this.createdCounter = Counter.builder("orders.created.total")
                .description("Total successfully created orders")
                .register(registry);

        this.failedCounter = Counter.builder("orders.failed.total")
                .description("Total failed order attempts")
                .register(registry);

        this.processingTimer = Timer.builder("orders.processing.duration")
                .description("Order processing time")
                .publishPercentiles(0.5, 0.95, 0.99)
                .register(registry);
    }

    public Order createOrder(OrderRequest request) {
        return processingTimer.record(() -> {
            try {
                Order order = doCreateOrder(request);
                createdCounter.increment();
                return order;
            } catch (Exception e) {
                failedCounter.increment();
                throw e;
            }
        });
    }

    private Order doCreateOrder(OrderRequest request) {
        // Business logic ...
        return new Order();
    }
}
```

### Controller with Observation

```java
import io.micrometer.observation.annotation.Observed;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping
    @Observed(name = "order.creation",
              contextualName = "creating-order",
              lowCardinalityKeyValues = {"order.type", "standard"})
    public Order create(@RequestBody OrderRequest request) {
        return orderService.createOrder(request);
    }
}
```

The `@Observed` annotation creates both a timer metric and a trace span, unifying metrics and traces with a single annotation.

## Micrometer Observation API

Starting with Micrometer 1.10 and Spring Boot 3, the **Observation API** provides a single abstraction that produces metrics, traces, and log correlation simultaneously.

```java
import io.micrometer.observation.Observation;
import io.micrometer.observation.ObservationRegistry;

@Service
public class InventoryService {

    private final ObservationRegistry observationRegistry;

    public InventoryService(ObservationRegistry observationRegistry) {
        this.observationRegistry = observationRegistry;
    }

    public StockLevel checkStock(String sku) {
        return Observation.createNotStarted("inventory.check", observationRegistry)
                .lowCardinalityKeyValue("warehouse", "zurich")
                .observe(() -> doCheckStock(sku));
    }
}
```

This single call generates:
- A **timer** metric named `inventory.check`
- A **trace span** named `inventory.check`
- **MDC context** so logs within `doCheckStock` carry the trace ID

## Common Anti-Patterns

Avoid these mistakes that make monitoring unreliable or expensive.

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Monitoring only infrastructure, not the application | CPU looks fine while users see errors | Add application-level metrics (error rate, latency) |
| Alerting on symptoms you cannot act on | Alerts fatigue leads to ignoring real issues | Alert on actionable conditions with clear runbooks |
| Unbounded tag cardinality | Prometheus OOM, slow queries | Never use user IDs, session IDs, or request IDs as tags |
| No baseline or SLO | Every alert threshold is a guess | Establish baseline metrics and define SLOs before alerting |
| Logging everything at DEBUG in production | Disk fills, performance degrades | Use INFO as default, enable DEBUG per-logger via Actuator when needed |
| Dashboard sprawl with no ownership | Nobody knows which dashboard to check | Assign owners, archive unused dashboards quarterly |

## Production Monitoring Checklist

Use this checklist when preparing a Java application for production.

**JVM Metrics**
- [ ] Heap usage and GC pauses are tracked
- [ ] Thread pool saturation is visible
- [ ] Metaspace and direct buffer usage have alerts

**Application Metrics**
- [ ] Request rate, error rate, and latency (RED method) are instrumented
- [ ] Business-critical operations have custom counters or timers
- [ ] Tag cardinality is bounded and documented

**Health Checks**
- [ ] Database connectivity is verified
- [ ] External service dependencies have health indicators
- [ ] Health endpoint is used by the load balancer or orchestrator

**Logging**
- [ ] Logs are structured (JSON)
- [ ] Trace IDs are included in every log line
- [ ] Log levels are appropriate (INFO default, WARN/ERROR for actionable events)

**Alerting**
- [ ] Four golden signals have alert rules
- [ ] Every alert has a runbook or at least a description
- [ ] Alert routing is configured (PagerDuty, Slack, email)
- [ ] Alerts have been tested with synthetic failures

**Dashboards**
- [ ] A service overview dashboard exists with RED metrics
- [ ] A JVM dashboard shows heap, GC, threads, and CPU
- [ ] Dashboards have a consistent layout across services

## Conclusion

Monitoring a Java application is not about picking one tool. It is about building layers: the JVM provides raw metrics through JMX, Micrometer normalizes them into a portable format, Spring Boot Actuator exposes them over HTTP, Prometheus stores them as time series, and Grafana turns them into dashboards with alerts. OpenTelemetry ties it all together by correlating metrics, logs, and traces into a unified view.

Start small. Add Actuator and the Prometheus registry to your Spring Boot application. Import a community Grafana dashboard. Set up alerts for the four golden signals. Once that baseline is running, expand into distributed tracing and structured logging. The investment pays for itself the first time a production incident is resolved in minutes instead of hours.
