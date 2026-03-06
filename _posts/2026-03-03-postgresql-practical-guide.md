---
layout: post
title: "PostgreSQL: A Practical Guide from Setup to Production"
date: 2026-03-03 10:00 +0100
categories: [Database, Infrastructure]
tags: [postgresql, sql, spring-boot, java, docker, database, jpa, flyway, performance]
description: A hands-on guide to PostgreSQL covering Docker setup, core SQL operations, indexing, JSON support, full-text search, Spring Boot integration with JPA and Flyway migrations, connection pooling, backup strategies, security hardening, and production best practices.
---

# PostgreSQL: A Practical Guide from Setup to Production

PostgreSQL is the most advanced open-source relational database. It has earned that reputation not through marketing but through decades of engineering: ACID compliance, MVCC concurrency, extensible type system, JSON support, full-text search, and a query planner that consistently outperforms expectations. Whether you are building a small side project or a system that handles millions of transactions per day, PostgreSQL scales with you.

This guide takes you from a fresh Docker setup to a production-ready Spring Boot application backed by PostgreSQL, covering every practical concept along the way.

## Why PostgreSQL

Before diving into setup, it is worth understanding what makes PostgreSQL stand out.

- **Standards compliance.** PostgreSQL follows the SQL standard more closely than any other open-source database. Your SQL knowledge transfers cleanly.
- **MVCC (Multi-Version Concurrency Control).** Readers never block writers and writers never block readers. Each transaction sees a consistent snapshot of the database without locking rows for reads.
- **Extensibility.** Custom data types, operators, index types, and procedural languages. Extensions like PostGIS (geospatial), pg_trgm (trigram similarity), and timescaledb (time-series) turn PostgreSQL into a specialized engine without replacing it.
- **JSON and document storage.** The `jsonb` type gives you the flexibility of a document database with the querying power of SQL. You can index JSON fields and use them in joins.
- **Full-text search.** Built-in text search with stemming, ranking, and custom dictionaries eliminates the need for a separate search engine in many cases.
- **Reliability.** Write-ahead logging (WAL), point-in-time recovery, and streaming replication are built in. PostgreSQL does not lose your data.

## Setting Up PostgreSQL with Docker

The fastest way to get PostgreSQL running locally is with Docker.

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:17-alpine
    container_name: postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: secret
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

Start the database:

```shell
docker compose up -d
```

Verify it is running:

```shell
docker exec -it postgres psql -U myapp -d myapp -c "SELECT version();"
```

You should see output like:

```
PostgreSQL 17.x on x86_64-pc-linux-musl, compiled by gcc ...
```

### Connecting with psql

The `psql` command-line client is the standard way to interact with PostgreSQL. Connect from within the container:

```shell
docker exec -it postgres psql -U myapp -d myapp
```

Useful `psql` commands:

| Command           | Description                        |
|-------------------|------------------------------------|
| `\l`              | List all databases                 |
| `\dt`             | List tables in the current schema  |
| `\d table_name`   | Describe a table's structure       |
| `\di`             | List indexes                       |
| `\du`             | List users and roles               |
| `\timing`         | Toggle query timing display        |
| `\q`              | Quit                               |

## Core SQL Operations

### Creating Tables

```sql
CREATE TABLE customers (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    full_name   VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id BIGINT       NOT NULL REFERENCES customers(id),
    status      VARCHAR(50)  NOT NULL DEFAULT 'PENDING',
    total       NUMERIC(12,2) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    BIGINT       NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product     VARCHAR(255) NOT NULL,
    quantity    INT          NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(10,2) NOT NULL
);
```

A few things to note:

- **`GENERATED ALWAYS AS IDENTITY`** is the modern replacement for `SERIAL`. It creates an auto-incrementing column backed by a sequence and prevents manual value insertion, which avoids sequence conflicts.
- **`TIMESTAMPTZ`** stores timestamps with time zone awareness. Always prefer it over `TIMESTAMP` -- it stores the value in UTC and converts to the session time zone on retrieval.
- **`NUMERIC(12,2)`** is exact decimal arithmetic. Never use `FLOAT` or `DOUBLE PRECISION` for monetary values.
- **`CHECK` constraints** enforce data integrity at the database level. A negative quantity is impossible, not just unlikely.

### Inserting Data

```sql
INSERT INTO customers (email, full_name)
VALUES ('alice@example.com', 'Alice Johnson')
RETURNING id, email, created_at;
```

The `RETURNING` clause is a PostgreSQL feature that returns the inserted row without a separate `SELECT`. It works on `INSERT`, `UPDATE`, and `DELETE`.

```sql
INSERT INTO orders (customer_id, status, total)
VALUES (1, 'CONFIRMED', 149.97)
RETURNING id;

INSERT INTO order_items (order_id, product, quantity, unit_price) VALUES
    (1, 'Mechanical Keyboard', 1, 89.99),
    (1, 'USB-C Cable',         2, 14.99),
    (1, 'Mouse Pad',           1, 29.99);
```

### Querying Data

Basic join with aggregation:

```sql
SELECT c.full_name,
       COUNT(o.id)    AS order_count,
       SUM(o.total)   AS total_spent
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.full_name
ORDER BY total_spent DESC NULLS LAST;
```

`NULLS LAST` ensures customers with no orders appear at the bottom rather than the top (PostgreSQL sorts NULLs as highest by default in descending order).

### Upsert with ON CONFLICT

PostgreSQL's `ON CONFLICT` clause handles the common "insert or update" pattern atomically:

```sql
INSERT INTO customers (email, full_name)
VALUES ('alice@example.com', 'Alice M. Johnson')
ON CONFLICT (email)
DO UPDATE SET full_name = EXCLUDED.full_name
RETURNING *;
```

`EXCLUDED` refers to the row that was proposed for insertion. This is atomic and avoids race conditions that arise from a separate SELECT-then-INSERT-or-UPDATE approach.

## Data Types Worth Knowing

PostgreSQL has a rich type system. These are the types you will use most often beyond the basics.

| Type          | Use Case                             | Example                                |
|---------------|--------------------------------------|----------------------------------------|
| `UUID`        | Distributed-safe primary keys        | `gen_random_uuid()`                    |
| `JSONB`       | Semi-structured data, API payloads   | `'{"key": "value"}'::jsonb`            |
| `TIMESTAMPTZ` | Points in time                       | `now()`                                |
| `INTERVAL`    | Durations and time arithmetic        | `INTERVAL '30 days'`                   |
| `NUMERIC`     | Exact decimal (money, measurements)  | `NUMERIC(12,2)`                        |
| `TEXT`         | Unbounded strings                    | No length limit, same performance as `VARCHAR` |
| `BOOLEAN`     | True/false flags                     | `TRUE`, `FALSE`                        |
| `INET`        | IPv4 and IPv6 addresses              | `'192.168.1.1'::inet`                  |
| `TSTZRANGE`   | Time ranges (booking systems)        | `tstzrange(now(), now() + '1 hour')`   |
| `ARRAY`       | Lists of values in a single column   | `'{a,b,c}'::text[]`                    |

### UUID Primary Keys

UUIDs are useful when you need IDs that are unique across distributed systems without a central sequence:

```sql
CREATE TABLE events (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    payload    JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

`gen_random_uuid()` is built into PostgreSQL 13+ and generates UUIDv4 values.

### JSONB

The `jsonb` type stores JSON in a decomposed binary format that supports indexing and efficient querying:

```sql
INSERT INTO events (event_type, payload)
VALUES ('order.created', '{"orderId": "ORD-001", "items": 3, "total": 149.97}');

SELECT id, payload->>'orderId' AS order_id, (payload->>'total')::numeric AS total
FROM events
WHERE event_type = 'order.created'
  AND (payload->>'total')::numeric > 100;
```

Operators:

| Operator | Meaning                         | Example                           |
|----------|---------------------------------|-----------------------------------|
| `->`     | Get JSON object field as JSON   | `payload->'items'`                |
| `->>`    | Get JSON object field as text   | `payload->>'orderId'`             |
| `@>`     | Contains (left contains right)  | `payload @> '{"items": 3}'`       |
| `?`      | Key exists                      | `payload ? 'orderId'`             |
| `jsonb_array_elements()` | Unnest JSON array | `jsonb_array_elements(payload->'tags')` |

## Indexing and Performance

Indexes are the single most impactful tool for query performance. PostgreSQL supports several index types, each optimized for different access patterns.

### B-tree (Default)

The default index type. Handles equality and range queries on scalar values.

```sql
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
CREATE INDEX idx_orders_created_at  ON orders (created_at);
```

### Composite Indexes

When queries frequently filter on multiple columns, a composite index avoids multiple index lookups:

```sql
CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC);
```

Column order matters. This index is useful for queries that filter by `status` and then sort by `created_at`, but not for queries that only filter by `created_at`.

### Partial Indexes

A partial index covers only rows matching a condition. This saves space and improves performance when you frequently query a subset of data:

```sql
CREATE INDEX idx_orders_pending ON orders (created_at)
WHERE status = 'PENDING';
```

This index is tiny compared to a full index on `created_at` and is used automatically when the query includes `WHERE status = 'PENDING'`.

### GIN Indexes for JSONB

GIN (Generalized Inverted Index) indexes are essential for efficient JSONB queries:

```sql
CREATE INDEX idx_events_payload ON events USING GIN (payload);
```

This enables fast `@>` (containment) and `?` (key existence) queries on the entire JSON document.

For queries that always access a specific key, a more targeted expression index is smaller and faster:

```sql
CREATE INDEX idx_events_order_id ON events ((payload->>'orderId'));
```

### GiST Indexes for Ranges and Geometry

GiST (Generalized Search Tree) indexes handle range types, geometric data, and full-text search:

```sql
CREATE TABLE bookings (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_id   INT NOT NULL,
    time_slot TSTZRANGE NOT NULL,
    EXCLUDE USING GIST (room_id WITH =, time_slot WITH &&)
);
```

The `EXCLUDE` constraint with a GiST index prevents overlapping bookings for the same room at the database level. No application logic needed.

### EXPLAIN ANALYZE

Always verify that your queries use indexes as expected:

```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42 AND status = 'PENDING';
```

Key things to look for in the output:

- **Index Scan** or **Index Only Scan** -- good, the index is being used.
- **Seq Scan** -- a full table scan. Acceptable on small tables, but problematic on large ones.
- **actual time** -- the real execution time in milliseconds.
- **rows** -- how many rows were actually processed versus estimated.

## Full-Text Search

PostgreSQL has built-in full-text search that handles stemming, ranking, and stop words without an external search engine.

### Creating a Search Index

```sql
ALTER TABLE customers ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (to_tsvector('english', full_name || ' ' || email)) STORED;

CREATE INDEX idx_customers_search ON customers USING GIN (search_vector);
```

The `GENERATED ALWAYS AS ... STORED` clause creates a computed column that is automatically maintained when `full_name` or `email` changes.

### Querying with Full-Text Search

```sql
SELECT full_name, email,
       ts_rank(search_vector, query) AS rank
FROM customers, to_tsquery('english', 'alice & johnson') AS query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

The `@@` operator matches a `tsvector` against a `tsquery`. `ts_rank` scores the match for relevance-based ordering.

### Query Syntax

| Syntax       | Meaning         | Example                    |
|--------------|-----------------|----------------------------|
| `&`          | AND             | `'alice & johnson'`        |
| `\|`         | OR              | `'alice \| bob'`           |
| `!`          | NOT             | `'alice & !bob'`           |
| `<->`        | Followed by     | `'alice <-> johnson'`      |
| `:*`         | Prefix match    | `'ali:*'`                  |

## Common Table Expressions and Window Functions

### CTEs (WITH Queries)

CTEs make complex queries readable by breaking them into named steps:

```sql
WITH monthly_revenue AS (
    SELECT date_trunc('month', created_at) AS month,
           SUM(total) AS revenue
    FROM orders
    WHERE status != 'CANCELLED'
    GROUP BY month
)
SELECT month,
       revenue,
       revenue - LAG(revenue) OVER (ORDER BY month) AS growth
FROM monthly_revenue
ORDER BY month;
```

This calculates monthly revenue and the month-over-month growth in a single query.

### Window Functions

Window functions perform calculations across a set of rows related to the current row without collapsing them into a single output row.

```sql
SELECT customer_id,
       total,
       created_at,
       ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC) AS order_rank,
       SUM(total)   OVER (PARTITION BY customer_id) AS customer_total,
       AVG(total)   OVER () AS global_avg
FROM orders;
```

| Function       | Description                                         |
|----------------|-----------------------------------------------------|
| `ROW_NUMBER()` | Sequential number within the partition               |
| `RANK()`       | Rank with gaps for ties                              |
| `DENSE_RANK()` | Rank without gaps                                    |
| `LAG()`        | Value from the previous row                          |
| `LEAD()`       | Value from the next row                              |
| `SUM() OVER`   | Running or partitioned sum                           |
| `AVG() OVER`   | Running or partitioned average                       |

## Transactions and Isolation Levels

PostgreSQL defaults to the **Read Committed** isolation level. Each statement within a transaction sees a snapshot that includes all committed transactions at the time the statement began.

```sql
BEGIN;
UPDATE orders SET status = 'SHIPPED' WHERE id = 1;
UPDATE orders SET status = 'SHIPPED' WHERE id = 2;
COMMIT;
```

If anything fails, roll back:

```sql
BEGIN;
UPDATE orders SET status = 'SHIPPED' WHERE id = 1;
-- something goes wrong
ROLLBACK;
```

### Isolation Levels

| Level              | Dirty Read | Non-Repeatable Read | Phantom Read | Use Case                       |
|--------------------|:----------:|:-------------------:|:------------:|--------------------------------|
| Read Committed     | No         | Possible            | Possible     | Default, suitable for most apps |
| Repeatable Read    | No         | No                  | No*          | Financial calculations          |
| Serializable       | No         | No                  | No           | Strict consistency requirements  |

*PostgreSQL's Repeatable Read actually prevents phantom reads too, going beyond the SQL standard.

Set the isolation level per transaction:

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
-- critical financial operations
COMMIT;
```

## Spring Boot Integration

Spring Boot with Spring Data JPA provides a productive way to work with PostgreSQL. Add the dependencies:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>
</dependency>
```

### Configuration

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/myapp
    username: myapp
    password: secret
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        jdbc.time_zone: UTC
```

Setting `ddl-auto: validate` ensures Hibernate checks the schema against your entities at startup but does not modify it. Schema changes should go through migrations, not Hibernate auto-DDL. Setting `open-in-view: false` prevents lazy loading from leaking into the controller layer, which is a common source of N+1 query problems.

### Entity Classes

```java
@Entity
@Table(name = "customers")
public class Customer {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @OneToMany(mappedBy = "customer", cascade = CascadeType.ALL)
    private List<Order> orders = new ArrayList<>();

    @PrePersist
    void prePersist() {
        this.createdAt = Instant.now();
    }
}
```

```java
@Entity
@Table(name = "orders")
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private Customer customer;

    @Column(nullable = false)
    private String status;

    @Column(nullable = false)
    private BigDecimal total;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItem> items = new ArrayList<>();

    @PrePersist
    void prePersist() {
        this.createdAt = Instant.now();
    }
}
```

Use `FetchType.LAZY` on `@ManyToOne` relationships. The default is `EAGER`, which loads related entities even when you do not need them.

### Repository

```java
public interface OrderRepository extends JpaRepository<Order, Long> {

    List<Order> findByCustomerIdAndStatus(Long customerId, String status);

    @Query("""
        SELECT o FROM Order o
        JOIN FETCH o.items
        WHERE o.customer.id = :customerId
        ORDER BY o.createdAt DESC
        """)
    List<Order> findOrdersWithItems(@Param("customerId") Long customerId);

    @Query(value = """
        SELECT date_trunc('month', created_at) AS month,
               SUM(total) AS revenue
        FROM orders
        WHERE status != 'CANCELLED'
        GROUP BY month
        ORDER BY month
        """, nativeQuery = true)
    List<Object[]> getMonthlyRevenue();
}
```

`JOIN FETCH` solves the N+1 problem by loading orders and their items in a single query. For complex analytics, native queries let you use PostgreSQL-specific features directly.

### Connection Pooling with HikariCP

Spring Boot uses HikariCP by default. Configure it for your workload:

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      idle-timeout: 300000
      max-lifetime: 1800000
      connection-timeout: 30000
      leak-detection-threshold: 60000
```

| Setting                     | Default | Recommendation                                     |
|-----------------------------|---------|-----------------------------------------------------|
| `maximum-pool-size`         | 10      | Start with `(2 * CPU cores) + disk spindles`        |
| `minimum-idle`              | Same    | Set equal to `maximum-pool-size` for stable pools   |
| `idle-timeout`              | 600000  | 5 minutes is reasonable                             |
| `max-lifetime`              | 1800000 | Must be less than PostgreSQL's `idle_in_transaction_session_timeout` |
| `leak-detection-threshold`  | 0       | Set to 60s in dev/staging to catch connection leaks |

Oversizing the pool hurts performance. A pool of 10 connections can handle far more concurrent requests than you might expect because most request time is spent outside the database (serialization, network I/O, business logic).

## Database Migrations with Flyway

Schema changes should be versioned and reproducible. Flyway integrates with Spring Boot out of the box.

Add the dependency:

```xml
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-database-postgresql</artifactId>
</dependency>
```

### Migration Files

Place SQL migration files in `src/main/resources/db/migration/`:

**V1__create_customers.sql**

```sql
CREATE TABLE customers (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    full_name   VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
```

**V2__create_orders.sql**

```sql
CREATE TABLE orders (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id BIGINT       NOT NULL REFERENCES customers(id),
    status      VARCHAR(50)  NOT NULL DEFAULT 'PENDING',
    total       NUMERIC(12,2) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_customer_id ON orders (customer_id);
CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC);
```

**V3__create_order_items.sql**

```sql
CREATE TABLE order_items (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    BIGINT       NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product     VARCHAR(255) NOT NULL,
    quantity    INT          NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(10,2) NOT NULL
);

CREATE INDEX idx_order_items_order_id ON order_items (order_id);
```

### Naming Convention

| Pattern                 | Purpose          |
|-------------------------|------------------|
| `V1__description.sql`   | Versioned migration (runs once, in order) |
| `R__description.sql`    | Repeatable migration (re-runs when checksum changes, useful for views and functions) |

Flyway runs migrations automatically at application startup. It tracks which migrations have been applied in a `flyway_schema_history` table.

### Configuration

```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true
```

Set `baseline-on-migrate: true` when introducing Flyway to an existing database. Flyway will create its history table and mark the current state as the baseline.

## Backup and Restore

### Logical Backups with pg_dump

`pg_dump` creates a logical backup as SQL statements or a custom archive format:

```shell
# SQL format (human-readable, larger)
docker exec postgres pg_dump -U myapp -d myapp > backup.sql

# Custom format (compressed, supports parallel restore)
docker exec postgres pg_dump -U myapp -d myapp -Fc > backup.dump
```

Restore from a custom-format backup:

```shell
docker exec -i postgres pg_restore -U myapp -d myapp --clean --if-exists < backup.dump
```

### Automating Backups

A simple cron job for daily backups with 7-day retention:

```bash
#!/bin/bash
BACKUP_DIR="/opt/backups/postgres"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"
docker exec postgres pg_dump -U myapp -d myapp -Fc > "$BACKUP_DIR/myapp_$TIMESTAMP.dump"
find "$BACKUP_DIR" -name "*.dump" -mtime +7 -delete
```

### Point-in-Time Recovery (PITR)

For production databases that cannot afford to lose any committed transaction, enable WAL archiving:

```ini
# postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/wal_archive/%f'
```

With WAL archiving enabled, you can restore to any point in time between the last base backup and the latest archived WAL segment. This is the gold standard for PostgreSQL disaster recovery.

## Securing PostgreSQL

### Authentication (pg_hba.conf)

PostgreSQL controls client authentication through `pg_hba.conf`. Each line specifies which users can connect from which hosts using which authentication method.

```
# TYPE  DATABASE  USER      ADDRESS         METHOD
local   all       postgres                  peer
host    myapp     myapp     172.16.0.0/12   scram-sha-256
host    all       all       0.0.0.0/0       reject
```

| Method           | Description                                        |
|------------------|----------------------------------------------------|
| `peer`           | OS username must match database username (local only) |
| `scram-sha-256`  | Password authentication with challenge-response    |
| `md5`            | Legacy password hashing (prefer scram-sha-256)     |
| `cert`           | Client certificate authentication via TLS          |
| `reject`         | Deny the connection                                |

### Role-Based Access Control

PostgreSQL uses roles for both users and groups:

```sql
-- Create a read-only role
CREATE ROLE readonly_role;
GRANT CONNECT ON DATABASE myapp TO readonly_role;
GRANT USAGE ON SCHEMA public TO readonly_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_role;

-- Create a user with the read-only role
CREATE USER reporting_user WITH PASSWORD 'str0ng_p@ss';
GRANT readonly_role TO reporting_user;
```

```sql
-- Create an application role with write access
CREATE ROLE app_role;
GRANT CONNECT ON DATABASE myapp TO app_role;
GRANT USAGE ON SCHEMA public TO app_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE ON SEQUENCES TO app_role;

CREATE USER myapp WITH PASSWORD 'app_s3cr3t';
GRANT app_role TO myapp;
```

### Enabling TLS

Generate or obtain certificates, then configure `postgresql.conf`:

```ini
ssl = on
ssl_cert_file = '/etc/postgresql/server.crt'
ssl_key_file  = '/etc/postgresql/server.key'
ssl_ca_file   = '/etc/postgresql/ca.crt'
```

Force TLS for all remote connections in `pg_hba.conf`:

```
hostssl  all  all  0.0.0.0/0  scram-sha-256
```

The `hostssl` type only matches TLS-encrypted connections. Combined with removing any plain `host` lines, this ensures no unencrypted traffic reaches the database.

In Spring Boot, enable SSL on the JDBC connection:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://db.example.com:5432/myapp?ssl=true&sslmode=verify-full&sslrootcert=/path/to/ca.crt
```

## Performance Tuning

### Essential postgresql.conf Settings

| Parameter                  | Default  | Recommendation                          | Purpose                                    |
|----------------------------|----------|-----------------------------------------|--------------------------------------------|
| `shared_buffers`           | 128 MB   | 25% of total RAM                        | PostgreSQL's main data cache               |
| `effective_cache_size`     | 4 GB     | 50-75% of total RAM                     | Hint for the query planner                 |
| `work_mem`                 | 4 MB     | 16-64 MB (depends on concurrency)       | Memory for sorts and hash operations       |
| `maintenance_work_mem`     | 64 MB    | 256 MB - 1 GB                           | Memory for VACUUM, CREATE INDEX            |
| `wal_buffers`              | -1       | 64 MB                                   | Write-ahead log buffer                     |
| `max_connections`          | 100      | Keep low, use connection pooling         | Each connection uses ~10 MB of RAM         |
| `random_page_cost`         | 4.0      | 1.1 for SSD storage                     | Planner cost estimate for random I/O       |
| `effective_io_concurrency` | 1        | 200 for SSD storage                     | Concurrent I/O operations for bitmap scans |

### VACUUM and Autovacuum

PostgreSQL's MVCC means that `UPDATE` and `DELETE` do not immediately free space. Dead tuples accumulate until `VACUUM` reclaims them. Autovacuum runs automatically, but heavy write workloads may need tuning:

```ini
autovacuum_vacuum_scale_factor = 0.05
autovacuum_analyze_scale_factor = 0.025
autovacuum_vacuum_cost_delay = 2ms
```

The defaults trigger vacuum when 20% of tuples are dead. For large tables, 5% (0.05) is a better threshold to prevent table bloat.

### Monitoring Slow Queries

Enable the `pg_stat_statements` extension to track query performance:

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

```ini
# postgresql.conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
```

Query the top slow queries:

```sql
SELECT query,
       calls,
       round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2)  AS avg_ms,
       rows
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

This is the most valuable performance diagnostic tool in PostgreSQL. Review it regularly.

## PostgreSQL vs MySQL

| Criteria                | PostgreSQL                          | MySQL (InnoDB)                  |
|-------------------------|-------------------------------------|---------------------------------|
| **SQL compliance**      | Extensive                           | Partial                         |
| **JSON support**        | `jsonb` with indexing               | `JSON` type, limited indexing   |
| **Full-text search**    | Built-in with ranking               | Basic, no ranking               |
| **Concurrency model**   | MVCC (readers never block writers)  | MVCC with gap locking           |
| **Extensibility**       | Custom types, operators, index types| Limited                         |
| **Partitioning**        | Declarative, range/list/hash        | Range/list/hash                 |
| **Replication**         | Streaming, logical                  | Binary log, group replication   |
| **Window functions**    | Full support since 8.4              | Added in 8.0                    |
| **CTEs**                | Full support, recursive CTEs        | Added in 8.0                    |
| **License**             | PostgreSQL License (permissive)     | GPL (dual licensed by Oracle)   |
| **Best for**            | Complex queries, analytics, GIS     | Simple CRUD, web applications   |

PostgreSQL is the better choice when you need advanced SQL features, JSON querying, full-text search, or complex analytical queries. MySQL is simpler to operate for straightforward CRUD workloads and has a larger ecosystem of managed hosting options.

## Production Checklist

| Action                                    | Why                                                    |
|-------------------------------------------|--------------------------------------------------------|
| Use Flyway or Liquibase for migrations    | Reproducible, version-controlled schema changes        |
| Set `ddl-auto: validate` in Spring Boot   | Prevents Hibernate from silently modifying your schema |
| Configure connection pooling (HikariCP)   | Reuse connections instead of creating new ones per request |
| Enable `pg_stat_statements`               | Identify and optimize slow queries                     |
| Set up automated backups with retention   | Protect against data loss                              |
| Enable WAL archiving for PITR            | Recover to any point in time                           |
| Use `TIMESTAMPTZ` for all timestamps      | Avoid time zone confusion                              |
| Create indexes based on EXPLAIN ANALYZE   | Data-driven optimization, not guesswork                |
| Tune autovacuum for write-heavy tables    | Prevent table bloat and query degradation              |
| Use TLS for all remote connections        | Encrypt data and credentials in transit                |
| Apply least-privilege roles               | Limit damage from compromised credentials              |
| Monitor connection count and pool usage   | Detect leaks before they cause outages                 |
| Set `statement_timeout` per role          | Prevent runaway queries from consuming resources       |
| Test restores, not just backups           | A backup you cannot restore is not a backup            |

## Summary

PostgreSQL is a database that rewards investment. The more you learn about its capabilities, the more you can push into the database layer and simplify your application code. Constraints, generated columns, JSONB queries, full-text search, window functions, and exclusion constraints all reduce the amount of logic you need to write, test, and maintain in your application.

The key takeaways from this guide:

- **Start with Docker Compose** for local development and use the same PostgreSQL version as production.
- **Use Flyway** for schema migrations. Never rely on Hibernate auto-DDL beyond initial prototyping.
- **Index based on evidence.** Run `EXPLAIN ANALYZE` on your actual queries before adding indexes.
- **JSONB and full-text search** can replace dedicated document stores and search engines for many use cases.
- **Connection pooling** with HikariCP is essential. A pool of 10 connections handles more load than you expect.
- **Backup and test your restores.** Automated pg_dump with retention is the minimum; WAL archiving with PITR is the standard for production.
- **Secure from day one.** TLS, scram-sha-256 authentication, and least-privilege roles are not optional in production.

With PostgreSQL running behind a well-configured Spring Boot application, you have a data layer that is reliable, performant, and ready to grow with your project.
