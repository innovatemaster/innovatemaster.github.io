---
layout: post
title: "RabbitMQ: A Hands-On Guide to Message-Driven Architecture"
date: 2026-03-03 10:00 +0100
categories: [Messaging, Infrastructure]
tags: [rabbitmq, amqp, messaging, spring-boot, java, docker, microservices, event-driven]
description: A practical, hands-on guide to RabbitMQ covering core concepts, Docker setup, exchange types, Spring Boot integration with producers and consumers, dead letter queues, retry strategies, TLS encryption, user permissions, and production best practices.
---

# RabbitMQ: A Hands-On Guide to Message-Driven Architecture

Modern distributed systems rarely work in isolation. Services need to communicate, and doing so synchronously with HTTP calls creates tight coupling, fragile chains of dependencies, and poor resilience. **Message brokers** solve this by decoupling producers from consumers, buffering load, and enabling asynchronous communication.

RabbitMQ is one of the most widely deployed open-source message brokers. It implements the **Advanced Message Queuing Protocol (AMQP)** and supports flexible routing, multiple messaging patterns, and a rich management interface. This guide takes you from zero to a working Spring Boot application that produces and consumes messages through RabbitMQ, covering every concept you need along the way.

## Core Concepts

Before writing any code, it is important to understand the building blocks of RabbitMQ.

### Producer, Exchange, Queue, Consumer

```
Producer ──▶ Exchange ──▶ Queue ──▶ Consumer
                │
                ├──▶ Queue B ──▶ Consumer B
                └──▶ Queue C ──▶ Consumer C
```

| Concept      | Description |
|--------------|-------------|
| **Producer** | Application that publishes messages to an exchange. |
| **Exchange** | Routing component that receives messages and distributes them to queues based on rules called *bindings*. |
| **Binding**  | A rule that links an exchange to a queue, optionally filtered by a *routing key* or *headers*. |
| **Queue**    | A buffer that stores messages until a consumer retrieves them. |
| **Consumer** | Application that subscribes to a queue and processes messages. |

A producer never sends directly to a queue. It always publishes to an exchange, and the exchange decides which queues receive the message.

### Exchange Types

RabbitMQ ships with four exchange types, each implementing a different routing strategy.

| Exchange Type | Routing Logic |
|---------------|---------------|
| **Direct**    | Delivers the message to queues whose binding key exactly matches the message's routing key. |
| **Fanout**    | Broadcasts every message to all bound queues, ignoring the routing key. |
| **Topic**     | Routes messages to queues based on wildcard pattern matching on the routing key (using `*` for one word and `#` for zero or more words). |
| **Headers**   | Routes based on message header attributes instead of the routing key. |

### Virtual Hosts

RabbitMQ supports **virtual hosts (vhosts)**, which act as logical groupings of exchanges, queues, and permissions. They let you run multiple isolated environments on a single broker instance -- useful for separating development, staging, and production traffic, or for multi-tenant setups.

## Setting Up RabbitMQ with Docker

The fastest way to get RabbitMQ running locally is with Docker. The `management` tag includes the web-based management UI.

```yaml
# docker-compose.yml
services:
  rabbitmq:
    image: rabbitmq:3-management
    container_name: rabbitmq
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

volumes:
  rabbitmq_data:
```

Start the broker:

```shell
docker compose up -d
```

After a few seconds, the **Management UI** is available at [http://localhost:15672](http://localhost:15672). Log in with `guest` / `guest`. The dashboard shows connections, channels, exchanges, and queues in real time and is invaluable for debugging.

### Verifying the Installation

Check the container logs to confirm the broker is ready:

```shell
docker logs rabbitmq
```

You should see a line similar to:

```
Server startup complete; 4 plugins started.
 * rabbitmq_management
 * rabbitmq_prometheus
 * rabbitmq_management_agent
 * rabbitmq_web_dispatch
```

## Spring Boot Integration

Spring AMQP provides first-class support for RabbitMQ. Add the starter to your project:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
</dependency>
```

Configure the connection in `application.yml`:

```yaml
spring:
  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: guest
```

### Declaring the Topology

Define the exchange, queue, and binding as Spring beans. This ensures they are created automatically when the application starts.

```java
@Configuration
public class RabbitMqConfig {

    public static final String EXCHANGE = "orders.exchange";
    public static final String QUEUE = "orders.queue";
    public static final String ROUTING_KEY = "orders.created";

    @Bean
    public DirectExchange ordersExchange() {
        return new DirectExchange(EXCHANGE);
    }

    @Bean
    public Queue ordersQueue() {
        return QueueBuilder.durable(QUEUE).build();
    }

    @Bean
    public Binding ordersBinding(Queue ordersQueue, DirectExchange ordersExchange) {
        return BindingBuilder.bind(ordersQueue)
                .to(ordersExchange)
                .with(ROUTING_KEY);
    }
}
```

`durable` means the queue survives broker restarts. Messages in a durable queue are persisted to disk if they are also published as **persistent** (the default in Spring AMQP).

### The Message DTO

A simple record shared between producer and consumer:

```java
public record OrderEvent(
        String orderId,
        String customerEmail,
        BigDecimal totalAmount,
        Instant createdAt
) {}
```

Spring AMQP uses Jackson for serialization when you configure a `Jackson2JsonMessageConverter`:

```java
@Bean
public Jackson2JsonMessageConverter messageConverter() {
    return new Jackson2JsonMessageConverter();
}

@Bean
public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory,
                                     Jackson2JsonMessageConverter converter) {
    RabbitTemplate template = new RabbitTemplate(connectionFactory);
    template.setMessageConverter(converter);
    return template;
}
```

### Publishing Messages (Producer)

```java
@Service
@RequiredArgsConstructor
public class OrderProducer {

    private final RabbitTemplate rabbitTemplate;

    public void publishOrderCreated(OrderEvent event) {
        rabbitTemplate.convertAndSend(
                RabbitMqConfig.EXCHANGE,
                RabbitMqConfig.ROUTING_KEY,
                event
        );
    }
}
```

You can trigger this from a REST controller:

```java
@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderProducer orderProducer;

    @PostMapping
    public ResponseEntity<String> createOrder(@RequestBody OrderEvent event) {
        orderProducer.publishOrderCreated(event);
        return ResponseEntity.accepted().body("Order event published");
    }
}
```

### Consuming Messages (Consumer)

```java
@Component
@Slf4j
public class OrderConsumer {

    @RabbitListener(queues = RabbitMqConfig.QUEUE)
    public void handleOrderCreated(OrderEvent event) {
        log.info("Received order: id={}, customer={}, amount={}",
                event.orderId(), event.customerEmail(), event.totalAmount());
        // process the order...
    }
}
```

`@RabbitListener` registers the method as a message consumer. Spring handles connection management, channel creation, and message deserialization behind the scenes.

### Testing It

Start the application and send a POST request:

```shell
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "ORD-001",
    "customerEmail": "alice@example.com",
    "totalAmount": 59.99,
    "createdAt": "2026-03-03T10:00:00Z"
  }'
```

The consumer logs should show:

```
Received order: id=ORD-001, customer=alice@example.com, amount=59.99
```

You can also verify in the Management UI under the **Queues** tab that messages are flowing through.

## Exchange Types in Practice

### Direct Exchange

The example above already uses a direct exchange. The message's routing key must **exactly match** the binding key. This is the most common pattern for point-to-point communication.

### Fanout Exchange

A fanout exchange broadcasts every message to all bound queues, ignoring the routing key entirely. This is useful for event notification patterns where multiple services need to react to the same event.

```java
@Configuration
public class FanoutConfig {

    public static final String FANOUT_EXCHANGE = "notifications.fanout";

    @Bean
    public FanoutExchange notificationExchange() {
        return new FanoutExchange(FANOUT_EXCHANGE);
    }

    @Bean
    public Queue emailQueue() {
        return QueueBuilder.durable("notifications.email").build();
    }

    @Bean
    public Queue smsQueue() {
        return QueueBuilder.durable("notifications.sms").build();
    }

    @Bean
    public Binding emailBinding(Queue emailQueue, FanoutExchange notificationExchange) {
        return BindingBuilder.bind(emailQueue).to(notificationExchange);
    }

    @Bean
    public Binding smsBinding(Queue smsQueue, FanoutExchange notificationExchange) {
        return BindingBuilder.bind(smsQueue).to(notificationExchange);
    }
}
```

Publishing to `notifications.fanout` delivers the message to both `notifications.email` and `notifications.sms`.

### Topic Exchange

Topic exchanges are the most flexible. Routing keys are dot-separated words, and bindings can use wildcards:

- `*` matches exactly one word
- `#` matches zero or more words

```java
@Configuration
public class TopicConfig {

    public static final String TOPIC_EXCHANGE = "logs.topic";

    @Bean
    public TopicExchange logsExchange() {
        return new TopicExchange(TOPIC_EXCHANGE);
    }

    @Bean
    public Queue allLogsQueue() {
        return QueueBuilder.durable("logs.all").build();
    }

    @Bean
    public Queue errorLogsQueue() {
        return QueueBuilder.durable("logs.errors").build();
    }

    @Bean
    public Binding allLogsBinding(Queue allLogsQueue, TopicExchange logsExchange) {
        return BindingBuilder.bind(allLogsQueue).to(logsExchange).with("logs.#");
    }

    @Bean
    public Binding errorLogsBinding(Queue errorLogsQueue, TopicExchange logsExchange) {
        return BindingBuilder.bind(errorLogsQueue).to(logsExchange).with("logs.*.error");
    }
}
```

| Routing Key          | `logs.#` (all) | `logs.*.error` (errors) |
|----------------------|:--------------:|:----------------------:|
| `logs.payment.error` | Yes            | Yes                    |
| `logs.payment.info`  | Yes            | No                     |
| `logs.auth.error`    | Yes            | Yes                    |
| `logs.debug`         | Yes            | No                     |

## Message Acknowledgment

By default, Spring AMQP uses **auto-acknowledge** mode: the message is acknowledged as soon as the listener method returns without throwing an exception. If the method throws, the message is re-queued (or rejected, depending on configuration).

For more control, switch to **manual acknowledgment**:

```yaml
spring:
  rabbitmq:
    listener:
      simple:
        acknowledge-mode: manual
```

```java
@RabbitListener(queues = RabbitMqConfig.QUEUE)
public void handleOrder(OrderEvent event, Channel channel,
                        @Header(AmqpHeaders.DELIVERY_TAG) long deliveryTag) throws IOException {
    try {
        processOrder(event);
        channel.basicAck(deliveryTag, false);
    } catch (Exception e) {
        channel.basicNack(deliveryTag, false, true);
    }
}
```

- `basicAck` tells RabbitMQ the message was processed successfully.
- `basicNack` with `requeue = true` puts the message back on the queue for another attempt.
- `basicNack` with `requeue = false` discards the message (or sends it to a dead letter queue if configured).

## Dead Letter Queues and Retry Strategy

When a message cannot be processed, it should not be lost. A **Dead Letter Queue (DLQ)** captures failed messages for later inspection or reprocessing.

### Configuring a DLQ

```java
@Configuration
public class DlqConfig {

    public static final String DLQ = "orders.dlq";
    public static final String DLX = "orders.dlx";

    @Bean
    public DirectExchange deadLetterExchange() {
        return new DirectExchange(DLX);
    }

    @Bean
    public Queue deadLetterQueue() {
        return QueueBuilder.durable(DLQ).build();
    }

    @Bean
    public Binding dlqBinding(Queue deadLetterQueue, DirectExchange deadLetterExchange) {
        return BindingBuilder.bind(deadLetterQueue)
                .to(deadLetterExchange)
                .with("orders.dead");
    }

    @Bean
    public Queue ordersQueueWithDlq() {
        return QueueBuilder.durable("orders.queue")
                .deadLetterExchange(DLX)
                .deadLetterRoutingKey("orders.dead")
                .build();
    }
}
```

When a message is rejected with `requeue = false`, RabbitMQ automatically routes it to the dead letter exchange, which then delivers it to the DLQ.

### Retry with Backoff

Spring AMQP supports automatic retries with exponential backoff:

```yaml
spring:
  rabbitmq:
    listener:
      simple:
        retry:
          enabled: true
          initial-interval: 1000
          multiplier: 2.0
          max-attempts: 4
          max-interval: 10000
```

This retries a failed message up to 4 times with intervals of 1s, 2s, 4s, and 8s (capped at 10s). After all retries are exhausted, the message is rejected and routed to the DLQ if configured.

## Prefetch and Concurrency

By default, RabbitMQ pushes messages to the consumer as fast as possible. This can overwhelm a slow consumer. The **prefetch count** limits how many unacknowledged messages the broker will send to a single consumer at a time.

```yaml
spring:
  rabbitmq:
    listener:
      simple:
        prefetch: 10
        concurrency: 2
        max-concurrency: 5
```

- `prefetch: 10` means each consumer receives at most 10 unacknowledged messages.
- `concurrency: 2` starts two consumer threads.
- `max-concurrency: 5` allows Spring to scale up to five threads under load.

Tuning these values depends on your workload. CPU-bound consumers benefit from higher concurrency, while I/O-bound consumers benefit from a moderate prefetch with fewer threads.

## Monitoring and Health Checks

### Spring Boot Actuator

Add the actuator dependency to expose a RabbitMQ health indicator:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, metrics
  endpoint:
    health:
      show-details: always
```

The `/actuator/health` endpoint now includes a `rabbit` section showing the connection status and broker version.

### Management UI Metrics

The RabbitMQ Management UI at port 15672 shows real-time metrics including:

- **Message rates** -- publish, deliver, acknowledge, and reject rates per second.
- **Queue depth** -- how many messages are waiting in each queue.
- **Consumer utilization** -- percentage of time consumers are actively processing.
- **Connection and channel counts** -- useful for detecting connection leaks.

For production environments, RabbitMQ also exposes a **Prometheus endpoint** (enabled by default with the management plugin) at `/api/metrics`, which integrates with Grafana dashboards.

## Securing RabbitMQ

The default RabbitMQ installation uses plain-text credentials, no encryption, and a `guest` account with full admin privileges. This is fine for local development, but every production deployment must address authentication, authorization, and transport encryption.

### Changing the Default Credentials

The `guest` / `guest` account has full access and, by default, can only connect from localhost. The first step is to create a dedicated admin user and remove the guest account.

Using the `rabbitmqctl` CLI inside the container:

```shell
docker exec rabbitmq rabbitmqctl add_user admin S3cur3P@ssw0rd
docker exec rabbitmq rabbitmqctl set_user_tags admin administrator
docker exec rabbitmq rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
docker exec rabbitmq rabbitmqctl delete_user guest
```

In a Docker Compose setup, you can set the initial credentials via environment variables:

```yaml
environment:
  RABBITMQ_DEFAULT_USER: admin
  RABBITMQ_DEFAULT_PASS: S3cur3P@ssw0rd
```

### User Management and Permissions

RabbitMQ has a fine-grained permission model. Each user is granted three permission patterns per vhost:

| Permission    | Controls |
|---------------|----------|
| **Configure** | Creating and deleting exchanges and queues (resource names matching the pattern). |
| **Write**     | Publishing messages to exchanges matching the pattern. |
| **Read**      | Consuming from queues and binding to exchanges matching the pattern. |

Patterns are regular expressions. For example, to allow a service to only interact with resources prefixed by `orders.`:

```shell
rabbitmqctl add_user order-service 0rd3rS3rv!c3
rabbitmqctl set_permissions -p / order-service "^orders\..*" "^orders\..*" "^orders\..*"
```

This user can create, publish to, and consume from any resource starting with `orders.`, but nothing else. Following the **principle of least privilege**, every service should have its own user scoped to only the resources it needs.

### User Tags and Management Access

User tags control access to the Management UI and HTTP API:

| Tag              | Access Level |
|------------------|--------------|
| **administrator** | Full access to everything, including user and policy management. |
| **monitoring**    | Read-only access to all exchanges, queues, connections, and channels. |
| **policymaker**   | Can manage policies and parameters for vhosts they have access to. |
| **management**    | Can access the Management UI for their own vhosts only. |
| *(none)*          | No Management UI access; AMQP connections only. |

Application service accounts typically need no tag at all -- they connect via AMQP and do not require Management UI access.

### Enabling TLS/SSL

TLS encrypts all traffic between clients and the broker, preventing eavesdropping and man-in-the-middle attacks.

#### Generating Certificates

For production, use certificates signed by your organization's CA or a public CA. For development and testing, you can generate a self-signed CA and certificates using OpenSSL:

```shell
mkdir -p tls && cd tls

# Generate CA key and certificate
openssl genrsa -out ca.key 4096
openssl req -x509 -new -key ca.key -sha256 -days 3650 \
  -out ca.crt -subj "/CN=RabbitMQ-CA"

# Generate server key and CSR
openssl genrsa -out server.key 4096
openssl req -new -key server.key \
  -out server.csr -subj "/CN=rabbitmq"

# Sign the server certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out server.crt -days 365 -sha256
```

#### Configuring the Broker

Create a `rabbitmq.conf` file that enables TLS:

```ini
# rabbitmq.conf
listeners.ssl.default = 5671
ssl_options.cacertfile = /etc/rabbitmq/tls/ca.crt
ssl_options.certfile   = /etc/rabbitmq/tls/server.crt
ssl_options.keyfile    = /etc/rabbitmq/tls/server.key
ssl_options.verify     = verify_peer
ssl_options.fail_if_no_peer_cert = false
```

| Setting                  | Purpose |
|--------------------------|---------|
| `listeners.ssl.default`  | The port for TLS-encrypted AMQP connections (conventionally 5671). |
| `verify = verify_peer`   | The broker verifies the client certificate against the CA. |
| `fail_if_no_peer_cert`   | Set to `true` for mutual TLS (mTLS), requiring every client to present a certificate. |

To also disable the plain-text AMQP listener so that unencrypted connections are impossible:

```ini
listeners.tcp = none
```

#### Docker Compose with TLS

Mount the certificates and configuration into the container:

```yaml
services:
  rabbitmq:
    image: rabbitmq:3-management
    container_name: rabbitmq
    ports:
      - "5671:5671"
      - "15671:15671"
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: S3cur3P@ssw0rd
    volumes:
      - ./rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf:ro
      - ./tls:/etc/rabbitmq/tls:ro
      - rabbitmq_data:/var/lib/rabbitmq

volumes:
  rabbitmq_data:
```

#### Securing the Management UI with HTTPS

By default the Management UI runs on HTTP. To enable HTTPS, add these lines to `rabbitmq.conf`:

```ini
management.ssl.port       = 15671
management.ssl.cacertfile = /etc/rabbitmq/tls/ca.crt
management.ssl.certfile   = /etc/rabbitmq/tls/server.crt
management.ssl.keyfile    = /etc/rabbitmq/tls/server.key
```

The Management UI is then accessible at `https://localhost:15671`.

### Connecting Spring Boot over TLS

Update `application.yml` to use the TLS port and provide the trust store:

```yaml
spring:
  rabbitmq:
    host: localhost
    port: 5671
    username: order-service
    password: 0rd3rS3rv!c3
    ssl:
      enabled: true
      trust-store: classpath:tls/truststore.p12
      trust-store-password: changeit
      trust-store-type: PKCS12
```

Generate the trust store from the CA certificate:

```shell
keytool -importcert -file tls/ca.crt -keystore src/main/resources/tls/truststore.p12 \
  -storetype PKCS12 -storepass changeit -alias rabbitmq-ca -noprompt
```

For **mutual TLS** (where the broker also verifies the client), add a key store containing the client certificate:

```yaml
spring:
  rabbitmq:
    ssl:
      enabled: true
      key-store: classpath:tls/client-keystore.p12
      key-store-password: changeit
      key-store-type: PKCS12
      trust-store: classpath:tls/truststore.p12
      trust-store-password: changeit
      trust-store-type: PKCS12
```

### Network-Level Security

Beyond TLS, restrict access at the network level:

- **Firewall rules** -- Only allow AMQP (5671) and management (15671) traffic from known application subnets. Never expose the broker to the public internet.
- **Docker networks** -- Place RabbitMQ and its consumers on a dedicated Docker network. Do not publish ports to the host unless necessary.
- **Reverse proxy** -- Put the Management UI behind a reverse proxy (e.g., Nginx or Traefik) with its own authentication layer, rate limiting, and access logs.

### Security Checklist

| Action | Why |
|--------|-----|
| Replace `guest` account with named users | Prevents unauthorized access with well-known credentials. |
| Scope permissions per service | Limits blast radius if a service is compromised. |
| Enable TLS on AMQP (port 5671) | Encrypts messages and credentials in transit. |
| Enable HTTPS on the Management UI | Prevents credential sniffing on the admin dashboard. |
| Disable plain-text listeners | Ensures no unencrypted fallback path exists. |
| Use mutual TLS for service-to-broker auth | Strongest authentication -- no passwords to rotate or leak. |
| Restrict network access with firewall rules | Defense in depth beyond application-level security. |
| Rotate credentials and certificates regularly | Limits exposure window if secrets are compromised. |

## Production Best Practices

### 1. Always Use Durable Queues and Persistent Messages

Durable queues survive broker restarts, and persistent messages are written to disk. Without both, you risk losing messages during outages.

### 2. Use Separate Vhosts per Environment

Keep development, staging, and production traffic isolated by using different virtual hosts. This prevents accidental cross-environment message delivery.

### 3. Enable Publisher Confirms

By default, `convertAndSend` is fire-and-forget. Enable publisher confirms to get notified when the broker has accepted a message:

```yaml
spring:
  rabbitmq:
    publisher-confirm-type: correlated
    publisher-returns: true
```

```java
rabbitTemplate.setConfirmCallback((correlationData, ack, cause) -> {
    if (!ack) {
        log.error("Message not confirmed: {}", cause);
    }
});
```

### 4. Set Queue Length Limits

Unbounded queues can consume all available memory and crash the broker. Use `x-max-length` or `x-max-length-bytes` to cap queue size:

```java
@Bean
public Queue boundedQueue() {
    return QueueBuilder.durable("orders.queue")
            .maxLength(100_000)
            .overflow(QueueBuilder.Overflow.rejectPublish)
            .build();
}
```

### 5. Monitor Queue Depth

Set up alerts when queue depth exceeds a threshold. A growing queue indicates that consumers cannot keep up with the publish rate, and you need to either scale consumers or investigate slow processing.

### 6. Use Lazy Queues for High-Volume Scenarios

Lazy queues store messages to disk as early as possible, reducing memory usage at the cost of slightly higher latency. This is useful when you expect large backlogs.

```java
@Bean
public Queue lazyQueue() {
    return QueueBuilder.durable("archive.queue")
            .lazy()
            .build();
}
```

### 7. Keep Messages Small

RabbitMQ is optimized for high message throughput, not large payloads. Avoid sending large binary blobs through the broker. Instead, store large data in object storage (e.g., S3) and pass a reference in the message.

## RabbitMQ vs Kafka: When to Choose Which

| Criteria                | RabbitMQ                          | Apache Kafka                     |
|-------------------------|-----------------------------------|----------------------------------|
| **Messaging model**     | Queue-based (push to consumers)   | Log-based (consumers pull)       |
| **Message ordering**    | Per queue                         | Per partition                    |
| **Message retention**   | Removed after acknowledgment      | Retained for a configurable time |
| **Routing flexibility** | Rich (exchanges, bindings, topics)| Topic-based partitioning         |
| **Throughput**          | Tens of thousands msg/s           | Millions of msg/s                |
| **Best for**            | Task queues, RPC, complex routing | Event streaming, event sourcing  |

Choose RabbitMQ when you need flexible routing, task distribution, or request-reply patterns. Choose Kafka when you need high-throughput event streaming, replay capability, or event sourcing.

## Summary

RabbitMQ is a mature, flexible message broker that fits naturally into Spring Boot applications. Its exchange-based routing model gives you fine-grained control over how messages flow between services, while features like dead letter queues, retries, and publisher confirms make it production-ready out of the box.

The key takeaways from this guide:

- **Exchanges route, queues buffer, consumers process** -- understanding this separation is fundamental.
- **Choose the right exchange type** for your use case: direct for point-to-point, fanout for broadcast, topic for pattern-based routing.
- **Dead letter queues** ensure failed messages are never silently lost.
- **Prefetch and concurrency tuning** are essential for matching consumer throughput to your workload.
- **Publisher confirms and durable queues** protect against message loss in production.
- **TLS encryption and scoped user permissions** are non-negotiable for any deployment beyond localhost.

With RabbitMQ running in Docker and Spring Boot handling the integration, you can have a working message-driven architecture in minutes and extend it with confidence as your system grows.
