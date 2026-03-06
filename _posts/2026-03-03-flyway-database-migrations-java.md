---
layout: post
title: "Flyway: Database Migrations Done Right in Java"
date: 2026-03-03 10:00 +0100
categories: [Java, Database]
tags: [java, flyway, database, migrations, spring-boot, sql, versioning, devops]
description: A practical guide to Flyway covering core concepts, SQL and Java-based migrations, Spring Boot integration, repeatable migrations, callbacks, the Flyway CLI, multi-environment strategies, and a comparison with Liquibase.
---

# Flyway: Database Migrations Done Right in Java

Every application that persists data eventually faces the same problem: the database schema needs to change. A column gets added, a table is renamed, an index is introduced for performance. When these changes live as ad-hoc SQL scripts shared over email or applied manually in production, things break. Environments drift apart, deployments become stressful, and nobody can answer the question: "What version of the schema is running right now?"

**Flyway** solves this by treating database changes as versioned migrations that are tracked, applied in order, and validated automatically. It works with plain SQL files, integrates directly into Spring Boot, and supports every major relational database. This guide walks through everything you need to use Flyway effectively in a Java project.

## Why Database Migrations Matter

Without a migration tool, teams typically resort to one of these strategies:

| Approach | Problem |
|---|---|
| Manual SQL scripts | No ordering guarantee, no record of what has been applied, error-prone in production |
| ORM auto-generation (e.g. `hibernate.ddl-auto=update`) | Unpredictable in production, cannot handle data migrations, no rollback path |
| Database dumps | Large, slow, environment-specific, impossible to review in a pull request |

A migration tool like Flyway brings the same discipline to database changes that version control brings to application code:

- Every change is an explicit, reviewable file in your repository.
- Changes are applied in a deterministic order.
- The tool tracks which migrations have already been applied.
- Environments can be reproduced reliably from scratch.

## Core Concepts

### Migrations

A **migration** is a single, atomic change to the database schema or data. Flyway supports three kinds of migrations:

| Type | Prefix | Purpose |
|---|---|---|
| **Versioned** | `V` | One-time changes applied in version order. This is the most common type. |
| **Undo** | `U` | Reverses a versioned migration. Available in Flyway Teams/Enterprise. |
| **Repeatable** | `R` | Applied every time their checksum changes. Useful for views, stored procedures, or seed data. |

### Naming Convention

Flyway discovers migrations by file name. The naming pattern for versioned migrations is:

```
V<version>__<description>.sql
```

- The prefix (`V`, `U`, or `R`) identifies the migration type.
- The version number uses dots or underscores as separators (e.g. `1`, `1.1`, `1_1`).
- A double underscore (`__`) separates the version from the description.
- The description uses underscores in place of spaces.

Examples:

```
V1__create_users_table.sql
V1.1__add_email_column_to_users.sql
V2__create_orders_table.sql
R__refresh_user_statistics_view.sql
```

### The Schema History Table

Flyway creates a metadata table called `flyway_schema_history` in the target database. This table records every migration that has been applied, along with its version, description, checksum, execution time, and result.

| installed_rank | version | description | type | script | checksum | installed_on | execution_time | success |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 | create users table | SQL | V1__create_users_table.sql | -1287534 | 2026-03-03 09:00:00 | 42 | true |
| 2 | 1.1 | add email column to users | SQL | V1.1__add_email_column_to_users.sql | 829471 | 2026-03-03 09:00:01 | 12 | true |

When Flyway runs, it compares the migrations on the filesystem against the history table and applies only those that have not yet been run.

## Setting Up Flyway with Spring Boot

Spring Boot has first-class Flyway support. Adding the dependency is enough to enable automatic migration on startup.

### Maven

```xml
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>
```

For databases that require an additional Flyway module (MySQL, MariaDB, SQL Server, Oracle), add the corresponding dialect dependency as well:

```xml
<!-- Required for MySQL / MariaDB -->
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-mysql</artifactId>
</dependency>

<!-- Required for PostgreSQL (included transitively in most setups) -->
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-database-postgresql</artifactId>
</dependency>
```

### Gradle

```groovy
implementation 'org.flywaydb:flyway-core'
// Add dialect module if needed
implementation 'org.flywaydb:flyway-database-postgresql'
```

### Application Properties

Spring Boot auto-configures Flyway using the same datasource your application already uses. The default migration location is `classpath:db/migration`.

```properties
# application.properties
spring.datasource.url=jdbc:postgresql://localhost:5432/myapp
spring.datasource.username=myapp
spring.datasource.password=secret

# Flyway settings (these are defaults, shown for clarity)
spring.flyway.enabled=true
spring.flyway.locations=classpath:db/migration
spring.flyway.baseline-on-migrate=false
```

Place your SQL files under `src/main/resources/db/migration/`, and Spring Boot will apply them automatically before the application context finishes loading.

```
src/
└── main/
    └── resources/
        └── db/
            └── migration/
                ├── V1__create_users_table.sql
                ├── V2__create_orders_table.sql
                └── V3__add_index_on_orders_user_id.sql
```

## Writing SQL Migrations

The most common approach is plain SQL. Each file contains one or more SQL statements, separated by semicolons.

### V1 -- Create Users Table

```sql
-- V1__create_users_table.sql

CREATE TABLE users (
    id         BIGSERIAL    PRIMARY KEY,
    username   VARCHAR(100) NOT NULL UNIQUE,
    email      VARCHAR(255) NOT NULL,
    created_at TIMESTAMP    NOT NULL DEFAULT now()
);
```

### V2 -- Create Orders Table

```sql
-- V2__create_orders_table.sql

CREATE TABLE orders (
    id         BIGSERIAL    PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users(id),
    total      NUMERIC(12,2) NOT NULL,
    status     VARCHAR(50)  NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP    NOT NULL DEFAULT now()
);
```

### V3 -- Add Index

```sql
-- V3__add_index_on_orders_user_id.sql

CREATE INDEX idx_orders_user_id ON orders(user_id);
```

### V4 -- Data Migration

Flyway is not limited to DDL. You can run data migrations in the same way:

```sql
-- V4__seed_default_admin_user.sql

INSERT INTO users (username, email)
VALUES ('admin', 'admin@example.com')
ON CONFLICT (username) DO NOTHING;
```

## Java-Based Migrations

When a schema change requires logic that is difficult or impossible to express in plain SQL -- conditional branching, calling external services, computing hashes -- Flyway supports Java-based migrations.

A Java migration implements `org.flywaydb.core.api.migration.JavaMigration` or, more conveniently, extends `BaseJavaMigration`. The class name follows the same naming convention as SQL files.

```java
package db.migration;

import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

import java.sql.PreparedStatement;
import java.sql.ResultSet;

public class V5__normalize_email_addresses extends BaseJavaMigration {

    @Override
    public void migrate(Context context) throws Exception {
        try (var select = context.getConnection()
                .prepareStatement("SELECT id, email FROM users")) {
            ResultSet rs = select.executeQuery();

            try (var update = context.getConnection()
                    .prepareStatement("UPDATE users SET email = ? WHERE id = ?")) {
                while (rs.next()) {
                    long id = rs.getLong("id");
                    String email = rs.getString("email").trim().toLowerCase();
                    update.setString(1, email);
                    update.setLong(2, id);
                    update.addBatch();
                }
                update.executeBatch();
            }
        }
    }
}
```

Place this class under `src/main/java/db/migration/`. Flyway scans this package by default.

Java migrations have access to a raw JDBC `Connection`, so they can do anything that SQL can do -- plus arbitrary Java logic. Use them sparingly; SQL migrations are easier to review and audit.

## Repeatable Migrations

Repeatable migrations are prefixed with `R` and have no version number. Instead of running once, they run every time their content (checksum) changes. This makes them ideal for objects that are recreated from scratch:

```sql
-- R__user_statistics_view.sql

CREATE OR REPLACE VIEW user_statistics AS
SELECT
    u.id         AS user_id,
    u.username,
    COUNT(o.id)  AS order_count,
    COALESCE(SUM(o.total), 0) AS total_spent
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
GROUP BY u.id, u.username;
```

Flyway always applies repeatable migrations **after** all pending versioned migrations, sorted alphabetically by description.

## Using the Flyway CLI

Flyway ships a standalone command-line tool that is useful for running migrations outside of application startup, in CI/CD pipelines, or against databases that are not connected to a Spring Boot application.

### Installation

```bash
# macOS (Homebrew)
brew install flyway

# Linux (manual download)
wget -qO- https://download.red-gate.com/maven/release/com/redgate/flyway/flyway-commandline/11.4.0/flyway-commandline-11.4.0-linux-x64.tar.gz | tar xz
sudo ln -s $(pwd)/flyway-11.4.0/flyway /usr/local/bin/flyway

# Docker
docker run --rm flyway/flyway -url=jdbc:postgresql://host:5432/myapp migrate
```

### Key Commands

| Command | Description |
|---|---|
| `flyway migrate` | Applies all pending migrations |
| `flyway info` | Shows the status of all migrations (pending, applied, failed) |
| `flyway validate` | Checks that applied migrations match the local files (catches tampering or accidental edits) |
| `flyway repair` | Removes failed migration entries from the history table and realigns checksums |
| `flyway clean` | **Drops all objects** in the configured schemas. Never run this in production. |
| `flyway baseline` | Baselines an existing database so Flyway can manage it going forward |

### Configuration File

The CLI reads configuration from `flyway.conf` or `flyway.toml` in the working directory:

```properties
# flyway.conf
flyway.url=jdbc:postgresql://localhost:5432/myapp
flyway.user=myapp
flyway.password=secret
flyway.locations=filesystem:./sql/migrations
flyway.schemas=public
```

## Callbacks

Flyway provides lifecycle callbacks that execute at specific points during the migration process. Callbacks let you run setup or teardown logic without embedding it in migration files.

### SQL Callbacks

Place SQL files with predefined names in the migration directory:

| Callback File | Triggered |
|---|---|
| `beforeMigrate.sql` | Before the entire migration run |
| `afterMigrate.sql` | After all migrations succeed |
| `beforeEachMigrate.sql` | Before each individual migration |
| `afterEachMigrate.sql` | After each individual migration succeeds |
| `beforeValidate.sql` | Before validation |
| `afterValidate.sql` | After validation |

Example -- refreshing materialized views after every migration run:

```sql
-- afterMigrate.sql
REFRESH MATERIALIZED VIEW CONCURRENTLY user_statistics;
```

### Java Callbacks

For more complex logic, implement the `Callback` interface:

```java
package com.example.flyway;

import org.flywaydb.core.api.callback.Callback;
import org.flywaydb.core.api.callback.Context;
import org.flywaydb.core.api.callback.Event;

public class LoggingCallback implements Callback {

    @Override
    public boolean supports(Event event, Context context) {
        return event == Event.AFTER_MIGRATE;
    }

    @Override
    public boolean canHandleInTransaction(Event event, Context context) {
        return true;
    }

    @Override
    public void handle(Event event, Context context) {
        System.out.println("Migration completed. Schema version: "
                + context.getMigrationInfo().getVersion());
    }

    @Override
    public String getCallbackName() {
        return "LoggingCallback";
    }
}
```

Register the callback in Spring Boot:

```java
@Configuration
public class FlywayConfig {

    @Bean
    public FlywayConfigurationCustomizer flywayCustomizer() {
        return configuration -> configuration.callbacks(new LoggingCallback());
    }
}
```

## Baseline: Adopting Flyway on an Existing Database

If your application already has a production database with an established schema, you cannot simply run all migrations from `V1` -- the tables already exist. Flyway's **baseline** feature solves this.

```bash
flyway -baselineVersion=4 -baselineDescription="existing_schema" baseline
```

This tells Flyway: "Assume that everything up to version 4 has already been applied." Future migrations starting from `V5` onward will be executed normally. In Spring Boot, set:

```properties
spring.flyway.baseline-on-migrate=true
spring.flyway.baseline-version=4
```

## Managing Multiple Environments

Real projects run the same application against different databases: local development, CI, staging, production. Flyway handles this seamlessly because each database maintains its own `flyway_schema_history` table.

### Environment-Specific Configuration with Spring Profiles

```properties
# application-dev.properties
spring.datasource.url=jdbc:h2:mem:devdb
spring.flyway.locations=classpath:db/migration,classpath:db/dev

# application-prod.properties
spring.datasource.url=jdbc:postgresql://prod-db:5432/myapp
spring.flyway.locations=classpath:db/migration
```

This setup lets you add test data or dev-only views under `db/dev` without polluting production.

### CI/CD Pipeline Integration

A typical pipeline applies migrations before deploying the application:

```yaml
# GitHub Actions example
- name: Run Flyway migrations
  run: |
    flyway -url=jdbc:postgresql://${{ secrets.DB_HOST }}:5432/myapp \
           -user=${{ secrets.DB_USER }} \
           -password=${{ secrets.DB_PASSWORD }} \
           -locations=filesystem:src/main/resources/db/migration \
           migrate

- name: Deploy application
  run: ./deploy.sh
```

Running migrations as a separate pipeline step (rather than on application startup) gives you a clear signal when a migration fails before rolling out new application code.

## Programmatic API

When you need full control outside of Spring Boot auto-configuration, Flyway provides a fluent Java API:

```java
import org.flywaydb.core.Flyway;

public class MigrationRunner {

    public static void main(String[] args) {
        Flyway flyway = Flyway.configure()
                .dataSource("jdbc:postgresql://localhost:5432/myapp", "myapp", "secret")
                .locations("classpath:db/migration")
                .schemas("public")
                .baselineOnMigrate(true)
                .load();

        flyway.migrate();
    }
}
```

This is useful for standalone tools, batch jobs, or integration test setup.

## Testing with Flyway

Flyway works particularly well in integration tests. Combined with an embedded database or Testcontainers, it guarantees that your test database exactly matches your production schema.

### Testcontainers Example

```java
@SpringBootTest
@Testcontainers
class OrderRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private OrderRepository orderRepository;

    @Test
    void shouldSaveAndRetrieveOrder() {
        // Flyway has already applied all migrations against the Testcontainer.
        // The schema is identical to production.
        Order order = new Order(1L, BigDecimal.valueOf(99.95), "PENDING");
        orderRepository.save(order);

        Optional<Order> found = orderRepository.findById(order.getId());
        assertThat(found).isPresent();
        assertThat(found.get().getStatus()).isEqualTo("PENDING");
    }
}
```

Spring Boot automatically runs Flyway against the Testcontainer before the first test method executes. Every test class gets a database with the full, current schema.

### Cleaning Between Tests

If tests modify data and you want a fresh database for each test class, use `@Sql` annotations or Flyway's `clean` + `migrate` cycle in a `@BeforeEach`:

```java
@Autowired
private Flyway flyway;

@BeforeEach
void resetDatabase() {
    flyway.clean();
    flyway.migrate();
}
```

This is effective but slow for large schemas. Prefer transactional rollback (`@Transactional` on test classes) when possible.

## Common Pitfalls and Best Practices

### Never Edit an Applied Migration

Once a versioned migration has been applied, its checksum is recorded in `flyway_schema_history`. Editing the file will cause Flyway to fail with a checksum mismatch error on the next run. If you need to fix something, create a new versioned migration.

### Keep Migrations Small and Focused

Each migration should make a single logical change. A file that creates a table, adds columns to another table, and inserts seed data is hard to understand and harder to debug when it fails.

### Use Transactions

Flyway wraps each migration in a transaction on databases that support transactional DDL (PostgreSQL, SQL Server, H2). On databases where DDL is auto-committed (MySQL, Oracle), a failed migration leaves the database in a partially applied state. For these databases, keep individual migrations especially small.

### Version Numbering Strategy

| Strategy | Example | Pros | Cons |
|---|---|---|---|
| Sequential integers | `V1`, `V2`, `V3` | Simple, readable | Merge conflicts when teams work in parallel |
| Timestamps | `V20260303090000` | Avoids merge conflicts | Harder to read at a glance |
| Dotted versions | `V1.1`, `V1.2`, `V2.0` | Groups related changes | More complex ordering |

For small teams, sequential integers work fine. Larger teams or monorepos benefit from timestamps to avoid two developers both creating `V42`.

### Separate Schema Changes from Data Migrations

Mixing DDL (schema changes) and DML (data changes) in the same migration makes it harder to reason about failures and rollback behavior. Consider a naming convention:

```
V10__create_products_table.sql        (DDL)
V11__seed_default_products.sql        (DML)
```

### Disable `hibernate.ddl-auto` in Production

When using Flyway with Hibernate, always set:

```properties
spring.jpa.hibernate.ddl-auto=validate
```

This tells Hibernate to verify that the entity model matches the database schema (which Flyway manages) without making any changes. Use `none` or `validate` -- never `update` or `create-drop` -- in production.

## Flyway vs Liquibase

Liquibase is the other major database migration tool in the Java ecosystem. Both tools solve the same problem, but they take different approaches.

| Aspect | Flyway | Liquibase |
|---|---|---|
| **Migration format** | SQL-first (with optional Java) | XML/YAML/JSON/SQL changelogs |
| **Learning curve** | Low -- just write SQL files | Moderate -- changelog DSL to learn |
| **Database abstraction** | None -- you write database-specific SQL | Changelog DSL generates SQL for multiple databases |
| **Rollback** | Manual (undo migrations in Teams edition) | Built-in rollback for most change types |
| **Diff / snapshot** | Not available in Community | Compare database states, generate changelogs |
| **Preconditions** | Via callbacks or Java migrations | Built-in precondition system |
| **Community edition** | Generous feature set | Generous feature set |
| **Philosophy** | SQL is the source of truth | Abstraction over SQL |

**Choose Flyway** when your team is comfortable writing raw SQL and you target a single database platform. The SQL-first approach means migrations double as documentation, and any DBA can read and review them without learning a DSL.

**Choose Liquibase** when you need to support multiple database vendors from the same changelog, require built-in rollback generation, or want a database diff tool.

Both integrate well with Spring Boot, Maven, Gradle, and CI/CD pipelines. The right choice depends on your team's preferences and project constraints rather than a clear technical winner.

## Quick Reference

| Task | Spring Boot Property / CLI Flag |
|---|---|
| Set migration locations | `spring.flyway.locations` / `-locations` |
| Enable baseline on first run | `spring.flyway.baseline-on-migrate=true` / `-baselineOnMigrate=true` |
| Set baseline version | `spring.flyway.baseline-version=1` / `-baselineVersion=1` |
| Change history table name | `spring.flyway.table=my_schema_history` / `-table=my_schema_history` |
| Target a specific version | `spring.flyway.target=5` / `-target=5` |
| Enable placeholder replacement | `spring.flyway.placeholders.myvar=value` / `-placeholders.myvar=value` |
| Set default schema | `spring.flyway.default-schema=myschema` / `-defaultSchema=myschema` |
| Out-of-order migrations | `spring.flyway.out-of-order=true` / `-outOfOrder=true` |
| Disable Flyway | `spring.flyway.enabled=false` |

## Conclusion

Flyway brings version control discipline to your database. By storing every schema change as a versioned file in your repository, you eliminate environment drift, make deployments repeatable, and give your team a clear audit trail of every change that has ever been applied.

The SQL-first approach keeps the learning curve flat. If you can write SQL, you can use Flyway. Spring Boot integration takes care of the wiring, and the CLI fills the gaps for CI/CD pipelines and operations. Combined with Testcontainers for integration tests, Flyway ensures that your test database faithfully mirrors production.

Start simple: add the dependency, create a `V1__initial_schema.sql` file, and let Spring Boot do the rest. Add complexity -- Java migrations, callbacks, multi-environment configuration -- only when you need it.
