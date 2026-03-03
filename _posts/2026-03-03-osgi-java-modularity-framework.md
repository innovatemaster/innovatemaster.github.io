---
layout: post
title: "OSGi: The Java Modularity Framework Explained"
date: 2026-03-03 10:00 +0100
categories: [Java, Architecture]
tags: [java, osgi, modularity, bundles, microservices, architecture, eclipse, karaf]
description: A comprehensive guide to OSGi -- the dynamic module system for Java. Covers bundles, the lifecycle model, declarative services, practical examples, and how OSGi compares to the Java Platform Module System (JPMS).
---

# OSGi: The Java Modularity Framework Explained

The **Open Service Gateway initiative (OSGi)** is a specification that defines a dynamic module system for the Java platform. It allows applications to be composed of loosely coupled, independently deployable components called **bundles**. Each bundle declares exactly what it exposes to the outside world and what it needs from other bundles. The OSGi runtime enforces these boundaries and manages the full lifecycle of every bundle -- including installing, starting, stopping, updating, and uninstalling them **at runtime without restarting the JVM**.

OSGi has been around since 1999 and powers some of the most prominent Java ecosystems: Eclipse IDE, Apache Karaf, Adobe Experience Manager, and many enterprise integration platforms. Despite the rise of microservices and container-based deployments, OSGi remains highly relevant wherever true runtime modularity inside a single JVM is required.

## Why Modularity Matters

Large Java applications tend to become **big balls of mud** over time. Classes reference each other freely, internal implementation details leak across package boundaries, and upgrading a single library can cascade into weeks of regression testing. The standard Java classpath is a flat namespace -- every public class is visible to every other class on the classpath, and there is no built-in way to enforce architectural boundaries at runtime.

Modularity addresses these problems:

- **Strong encapsulation** -- only explicitly exported packages are visible to other modules.
- **Explicit dependencies** -- every module declares what it requires, making the dependency graph inspectable and verifiable.
- **Independent lifecycles** -- modules can be updated or replaced without restarting the entire application.
- **Parallel development** -- teams can work on separate modules with well-defined contracts.

OSGi was the first widely adopted framework to bring all of these qualities to the Java ecosystem.

## Core Concepts

### Bundles

A **bundle** is the unit of modularity in OSGi. Physically, it is a standard JAR file with additional metadata in its `META-INF/MANIFEST.MF`. This metadata tells the OSGi framework what the bundle provides and what it needs.

A minimal manifest looks like this:

```
Bundle-SymbolicName: com.example.greeting
Bundle-Version: 1.0.0
Bundle-Activator: com.example.greeting.Activator
Import-Package: org.osgi.framework;version="[1.8,2)"
Export-Package: com.example.greeting.api;version="1.0.0"
```

| Header | Purpose |
|---|---|
| `Bundle-SymbolicName` | Uniquely identifies the bundle together with its version. |
| `Bundle-Version` | Semantic version of the bundle. |
| `Bundle-Activator` | Optional class called when the bundle starts and stops. |
| `Import-Package` | Packages the bundle needs from other bundles, with version ranges. |
| `Export-Package` | Packages the bundle makes available to other bundles. |

Packages that are **not** listed in `Export-Package` are invisible to other bundles even if the classes are `public`. This is the foundation of strong encapsulation in OSGi.

### The Lifecycle Model

Every bundle in an OSGi framework goes through a well-defined set of states:

```
INSTALLED  -->  RESOLVED  -->  STARTING  -->  ACTIVE
                                                 |
                                              STOPPING  -->  UNINSTALLED
```

| State | Meaning |
|---|---|
| **INSTALLED** | The bundle JAR is known to the framework but its dependencies have not been resolved yet. |
| **RESOLVED** | All `Import-Package` requirements are satisfied. The bundle is ready to be started. |
| **STARTING** | The `BundleActivator.start()` method is being executed. |
| **ACTIVE** | The bundle is running. |
| **STOPPING** | The `BundleActivator.stop()` method is being executed. |
| **UNINSTALLED** | The bundle has been removed from the framework. |

Transitions between states can happen **at runtime**. You can install a new version of a bundle, stop the old one, and start the new one -- all while the rest of the application keeps running. This is one of OSGi's most powerful features and is heavily used in IoT gateways, application servers, and plugin-based desktop applications.

### Class Loading

OSGi replaces the standard flat classpath with a **graph of class loaders**. Each bundle gets its own class loader that can only see:

1. The `java.*` packages from the boot class loader.
2. Packages explicitly imported via `Import-Package` (resolved from another bundle's `Export-Package`).
3. The bundle's own classes and resources.

This strict isolation prevents version conflicts. Two bundles can depend on different versions of the same library without causing `ClassCastException` or `NoSuchMethodError` at runtime -- a problem commonly known as **JAR hell**.

## The Service Layer

Bundles communicate through the OSGi **Service Registry**. A bundle can register a service (typically a Java interface implementation) into the registry, and other bundles can look it up and consume it. Services are dynamic -- they can appear and disappear at any time as bundles are started and stopped.

### Registering a Service Programmatically

```java
public class Activator implements BundleActivator {

    private ServiceRegistration<GreetingService> registration;

    @Override
    public void start(BundleContext context) {
        GreetingService service = new EnglishGreetingService();
        registration = context.registerService(
            GreetingService.class, service, null
        );
    }

    @Override
    public void stop(BundleContext context) {
        if (registration != null) {
            registration.unregister();
        }
    }
}
```

### Consuming a Service Programmatically

```java
public class Activator implements BundleActivator {

    @Override
    public void start(BundleContext context) {
        ServiceReference<GreetingService> ref =
            context.getServiceReference(GreetingService.class);

        if (ref != null) {
            GreetingService service = context.getService(ref);
            System.out.println(service.greet("World"));
            context.ungetService(ref);
        }
    }

    @Override
    public void stop(BundleContext context) {}
}
```

While this works, the programmatic approach is verbose and error-prone -- you have to manually track service availability and handle the case where a service is not yet registered. That is why modern OSGi development uses **Declarative Services**.

## Declarative Services (DS)

Declarative Services is a component model built on top of OSGi that eliminates most of the boilerplate. Instead of writing `BundleActivator` classes and manually interacting with the service registry, you annotate your components and let the runtime handle wiring.

### Providing a Service with DS

```java
@Component(service = GreetingService.class)
public class EnglishGreetingService implements GreetingService {

    @Override
    public String greet(String name) {
        return "Hello, " + name + "!";
    }
}
```

The `@Component` annotation tells the DS runtime to register this class as a `GreetingService` in the service registry when its bundle is active.

### Consuming a Service with DS

```java
@Component
public class GreetingCommand {

    @Reference
    private GreetingService greetingService;

    @Activate
    public void activate() {
        System.out.println(greetingService.greet("OSGi"));
    }
}
```

The `@Reference` annotation declares a mandatory dependency on `GreetingService`. The DS runtime will only activate `GreetingCommand` once a `GreetingService` is available. If the service disappears, the component is deactivated automatically.

### Reference Cardinality and Policy

DS supports fine-grained control over service references:

| Cardinality | Meaning |
|---|---|
| `MANDATORY` (default) | Exactly one instance must be available. |
| `OPTIONAL` | Zero or one instance. |
| `MULTIPLE` | Zero or more instances. |
| `AT_LEAST_ONE` | One or more instances. |

Combined with the **policy** attribute (`STATIC` or `DYNAMIC`), you can control whether the component is restarted or dynamically updated when services come and go.

```java
@Reference(
    cardinality = ReferenceCardinality.MULTIPLE,
    policy = ReferencePolicy.DYNAMIC
)
private volatile List<GreetingService> greetingServices;
```

## Building Bundles with Maven

The most common way to build OSGi bundles is with the **Maven Bundle Plugin** (now maintained as `bnd-maven-plugin`). It inspects your bytecode and generates the `MANIFEST.MF` automatically.

```xml
<plugin>
    <groupId>biz.aQute.bnd</groupId>
    <artifactId>bnd-maven-plugin</artifactId>
    <version>7.1.0</version>
    <executions>
        <execution>
            <goals>
                <goal>bnd-process</goal>
            </goals>
        </execution>
    </executions>
</plugin>

<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-jar-plugin</artifactId>
    <configuration>
        <archive>
            <manifestFile>
                ${project.build.outputDirectory}/META-INF/MANIFEST.MF
            </manifestFile>
        </archive>
    </configuration>
</plugin>
```

You control bundle metadata through a `bnd.bnd` file in the project root:

```
Bundle-SymbolicName: com.example.greeting
Bundle-Version: 1.0.0
Export-Package: com.example.greeting.api
-sources: true
```

The `bnd` tool is smart about defaults. If you do not specify `Import-Package`, it analyzes the bytecode and generates the correct imports automatically.

## OSGi Runtimes

Several mature OSGi runtime implementations are available:

| Runtime | Maintained By | Notes |
|---|---|---|
| **Apache Felix** | Apache Software Foundation | Lightweight, widely embedded (e.g. in Adobe AEM). |
| **Eclipse Equinox** | Eclipse Foundation | Powers the Eclipse IDE and Eclipse RCP applications. |
| **Apache Karaf** | Apache Software Foundation | Enterprise container built on top of Felix or Equinox, adds shell, logging, provisioning. |
| **Knopflerfish** | Makewave | One of the earliest implementations, still maintained. |

### Running Bundles on Apache Karaf

Apache Karaf is a popular choice for server-side OSGi deployments. It provides a rich shell, hot deployment via a `deploy/` folder, and features like configuration management, JAAS security, and clustering.

```bash
# Start Karaf
bin/karaf

# In the Karaf shell, install a bundle from a Maven repository
karaf@root()> bundle:install mvn:com.example/greeting-impl/1.0.0

# Start the bundle
karaf@root()> bundle:start com.example.greeting

# List all bundles
karaf@root()> bundle:list

# Check the services registered by a bundle
karaf@root()> service:list GreetingService
```

Karaf also supports **features** -- named groups of bundles and configuration that can be installed as a single unit:

```xml
<features name="greeting-features" xmlns="http://karaf.apache.org/xmlns/features/v1.6.0">
    <feature name="greeting" version="1.0.0">
        <bundle>mvn:com.example/greeting-api/1.0.0</bundle>
        <bundle>mvn:com.example/greeting-impl/1.0.0</bundle>
        <bundle>mvn:com.example/greeting-command/1.0.0</bundle>
    </feature>
</features>
```

## A Practical Example: Plugin Architecture

One of OSGi's strengths is building extensible applications where plugins can be added and removed at runtime. Consider a text processing application that supports multiple output formats.

### The API Bundle

```java
package com.example.formatter.api;

public interface TextFormatter {
    String getFormatName();
    String format(String input);
}
```

This package is exported. Any bundle can implement `TextFormatter`.

### A Plugin Bundle (Markdown Formatter)

```java
package com.example.formatter.markdown;

import com.example.formatter.api.TextFormatter;
import org.osgi.service.component.annotations.Component;

@Component
public class MarkdownFormatter implements TextFormatter {

    @Override
    public String getFormatName() {
        return "Markdown";
    }

    @Override
    public String format(String input) {
        return input
            .replaceAll("(?m)^# (.+)$", "<h1>$1</h1>")
            .replaceAll("(?m)^## (.+)$", "<h2>$1</h2>")
            .replaceAll("\\*\\*(.+?)\\*\\*", "<strong>$1</strong>");
    }
}
```

### The Consumer Bundle

```java
package com.example.formatter.app;

import com.example.formatter.api.TextFormatter;
import org.osgi.service.component.annotations.*;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

@Component(immediate = true)
public class FormatterAggregator {

    private final List<TextFormatter> formatters = new CopyOnWriteArrayList<>();

    @Reference(
        cardinality = ReferenceCardinality.MULTIPLE,
        policy = ReferencePolicy.DYNAMIC
    )
    void addFormatter(TextFormatter formatter) {
        formatters.add(formatter);
        System.out.println("Formatter added: " + formatter.getFormatName());
    }

    void removeFormatter(TextFormatter formatter) {
        formatters.remove(formatter);
        System.out.println("Formatter removed: " + formatter.getFormatName());
    }

    public List<TextFormatter> getFormatters() {
        return List.copyOf(formatters);
    }
}
```

When a new formatter bundle is deployed at runtime, the `addFormatter` method is called automatically. When it is stopped, `removeFormatter` fires. The application seamlessly adapts to available plugins without any restarts.

## OSGi vs JPMS (Java Platform Module System)

Java 9 introduced the **Java Platform Module System** (JPMS, also known as Project Jigsaw) with `module-info.java`. While both OSGi and JPMS address modularity, they differ significantly:

| Aspect | OSGi | JPMS |
|---|---|---|
| **Introduced** | 1999 (Release 1) | 2017 (Java 9) |
| **Module Descriptor** | `MANIFEST.MF` in the JAR | `module-info.java` compiled into the module |
| **Granularity** | Package-level imports/exports | Module-level requires/exports |
| **Versioning** | Built-in semantic versioning with ranges | No version support |
| **Runtime Dynamism** | Full lifecycle: install, start, stop, update, uninstall at runtime | Static -- modules are fixed at startup |
| **Service Registry** | Central service registry with dynamic binding | `ServiceLoader` (limited, no lifecycle) |
| **Multiple Versions** | Supported (each bundle has its own class loader) | Not supported |
| **Adoption** | Rich ecosystem, many frameworks | JDK itself, limited application adoption |
| **Tooling** | bnd, Maven plugins, Karaf, Eclipse PDE | Built into `javac` and `java` |

**JPMS** is excellent for modularizing the JDK itself and for applications that need compile-time module boundaries with minimal runtime overhead. **OSGi** shines when you need runtime dynamism, plugin architectures, hot deployment, or multiple versions of the same library running side by side.

The two systems can coexist. A bundle can contain a `module-info.java` alongside its OSGi manifest. The bnd tool supports generating both.

## When to Use OSGi

OSGi is a strong fit for:

- **Plugin-based applications** -- where end users or third parties extend the application at runtime (IDEs, CMS platforms, IoT gateways).
- **Long-running server processes** -- where restarting the JVM for every update is costly or disruptive.
- **Embedded and IoT systems** -- where resource constraints demand fine-grained control over which modules are loaded.
- **Multi-tenant platforms** -- where different tenants may require different versions of the same component.

OSGi may be overkill for:

- **Simple microservices** -- if each service is a small, independently deployed unit with its own JVM, the container and orchestrator (Docker, Kubernetes) already provide isolation and lifecycle management.
- **Short-lived applications** -- batch jobs, CLI tools, or serverless functions gain little from runtime dynamism.
- **Greenfield applications** -- if you do not need hot deployment or plugin extensibility, JPMS or a framework like Spring Modulith may be simpler.

## Conclusion

OSGi brings true runtime modularity to the Java platform. Its bundle model enforces strong encapsulation, its lifecycle management enables hot deployment, and its service layer provides dynamic, loosely coupled communication between components. While the learning curve is steeper than dropping JARs on a flat classpath, the payoff is a system that is maintainable, extensible, and resilient to change.

If your application needs to evolve at runtime -- accepting new plugins, swapping implementations, or updating components without downtime -- OSGi remains one of the most mature and battle-tested solutions available.
