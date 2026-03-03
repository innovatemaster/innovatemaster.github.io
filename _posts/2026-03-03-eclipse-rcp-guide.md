---
layout: post
title: "Eclipse RCP: Building Desktop Applications with the Rich Client Platform"
date: 2026-03-03 10:00 +0100
categories: [Java, Desktop]
tags: [java, eclipse-rcp, osgi, swt, jface, desktop-applications, plugin-architecture, e4]
description: A practical guide to Eclipse RCP covering its architecture, OSGi runtime, SWT and JFace UI toolkits, the application model, extension points, and how to build, test, and distribute professional desktop applications.
---

# Eclipse RCP: Building Desktop Applications with the Rich Client Platform

The Eclipse IDE is one of the most successful Java applications ever built. What many developers don't realize is that the same modular framework powering Eclipse can be used to build any desktop application. **Eclipse RCP** (Rich Client Platform) extracts the non-IDE parts of Eclipse into a general-purpose application framework for creating professional, cross-platform desktop software.

Eclipse RCP applications run on Windows, macOS, and Linux from a single codebase. They benefit from a mature plugin architecture, a native-look widget toolkit, and a well-defined application lifecycle. This guide walks through the core concepts, shows how to build a working application, and covers the modern **Eclipse 4 (e4)** programming model.

## Why Eclipse RCP?

Desktop development in Java has historically meant Swing or JavaFX. Eclipse RCP offers a different proposition:

| Feature | Eclipse RCP | Swing | JavaFX |
|---|---|---|---|
| Native look and feel | Yes (SWT) | Pluggable L&F | CSS-themed |
| Modularity | OSGi bundles | Manual | JPMS or manual |
| Plugin architecture | Built-in | None | None |
| Update mechanism | p2 provisioning | None | None |
| Declarative UI model | Application model (e4) | No | FXML |
| Cross-platform packaging | PDE Build / Tycho | jpackage | jpackage |

Choose Eclipse RCP when you need a **modular, extensible** desktop application where third parties or separate teams contribute plugins independently. It is particularly popular in scientific, engineering, and enterprise tooling.

## Architecture Overview

An Eclipse RCP application is composed of several layers, each building on the one below.

```
┌────────────────────────────────────────────┐
│           Your Application Plugins         │
├────────────────────────────────────────────┤
│    Eclipse Application Model (e4 / 3.x)   │
├────────────────────────────────────────────┤
│         JFace  (structured viewers)        │
├────────────────────────────────────────────┤
│      SWT  (native widget toolkit)          │
├────────────────────────────────────────────┤
│    Equinox  (OSGi runtime)                 │
├────────────────────────────────────────────┤
│              JVM                           │
└────────────────────────────────────────────┘
```

### Equinox and OSGi

At the foundation sits **Equinox**, Eclipse's implementation of the OSGi specification. Every piece of an RCP application -- including your own code -- is packaged as an **OSGi bundle** (a JAR with extra metadata in `META-INF/MANIFEST.MF`). OSGi provides:

- **Module isolation** -- each bundle has its own classloader
- **Explicit dependency declaration** -- bundles declare what they import and export
- **Lifecycle management** -- bundles can be installed, started, stopped, and updated at runtime
- **Service registry** -- bundles publish and consume services dynamically

A minimal `MANIFEST.MF` for a bundle looks like this:

```
Manifest-Version: 1.0
Bundle-ManifestVersion: 2
Bundle-Name: My Plugin
Bundle-SymbolicName: com.example.myplugin;singleton:=true
Bundle-Version: 1.0.0.qualifier
Bundle-Activator: com.example.myplugin.Activator
Require-Bundle: org.eclipse.core.runtime,
 org.eclipse.e4.ui.di
Bundle-RequiredExecutionEnvironment: JavaSE-17
```

### SWT -- Standard Widget Toolkit

SWT is a low-level UI toolkit that delegates rendering to the operating system's native widget libraries. On Windows it uses Win32, on macOS it uses Cocoa, and on Linux it uses GTK. This means an SWT application looks and feels like a native application on every platform.

```java
Display display = new Display();
Shell shell = new Shell(display);
shell.setText("SWT Hello World");
shell.setSize(400, 300);

Label label = new Label(shell, SWT.NONE);
label.setText("Hello from SWT!");
label.pack();

shell.open();
while (!shell.isDisposed()) {
    if (!display.readAndDispatch()) {
        display.sleep();
    }
}
display.dispose();
```

SWT uses an explicit resource management model. You must dispose of resources (colors, fonts, images) when they are no longer needed; the garbage collector will not do it for you.

### JFace -- Structured UI on Top of SWT

JFace sits on top of SWT and provides higher-level abstractions: **viewers** (table, tree, list), **dialogs**, **wizards**, **actions**, and **data binding**. The most important concept is the **viewer**, which separates content from presentation using content providers and label providers.

```java
TableViewer viewer = new TableViewer(parent, SWT.BORDER | SWT.FULL_SELECTION);
viewer.setContentProvider(ArrayContentProvider.getInstance());
viewer.setLabelProvider(new LabelProvider() {
    @Override
    public String getText(Object element) {
        return ((Person) element).getName();
    }
});
viewer.setInput(personList);
```

JFace viewers automatically handle selection events, sorting, filtering, and refreshing.

## Setting Up the Development Environment

Eclipse RCP development uses the **Eclipse IDE for RCP and RAP Developers** package.

1. Download the package from [eclipse.org/downloads](https://www.eclipse.org/downloads/packages/).
2. Extract and launch the IDE.
3. Ensure you have a **JDK 17+** configured under *Window > Preferences > Java > Installed JREs*.
4. Open the **Plug-in Development** perspective via *Window > Perspective > Open Perspective > Other > Plug-in Development*.

The IDE includes the **Plug-in Development Environment (PDE)**, which provides editors for manifests, extension points, target platforms, and product configurations.

### Target Platform

A **target platform** defines which bundles are available at compile time and runtime. By default it points to the running IDE installation, but for reproducible builds you should define a custom target:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?pde version="3.8"?>
<target name="My Target" sequenceNumber="1">
    <locations>
        <location includeAllPlatforms="false" includeMode="planner"
                  type="InstallableUnit">
            <repository location="https://download.eclipse.org/releases/2025-12"/>
            <unit id="org.eclipse.e4.rcp.feature.group" version="0.0.0"/>
        </location>
    </locations>
</target>
```

Save this as a `.target` file. Open it in the IDE and click **Set as Active Target Platform**. The IDE resolves all dependencies from the specified repository.

## The Eclipse 4 Application Model

Modern Eclipse RCP uses the **e4 application model**, a declarative description of the application's UI structure stored in an `Application.e4xmi` file. The model is a tree of UI elements:

```
MApplication
 └── MTrimmedWindow
      ├── MPerspectiveStack
      │    └── MPerspective
      │         ├── MPartSashContainer
      │         │    ├── MPart (Editor)
      │         │    └── MPart (View)
      │         └── MPartStack
      └── MTrimBar
           ├── MToolBar
           └── MHandledToolItem
```

Each model element maps to a Java class annotated with dependency injection annotations. The e4 workbench creates the widgets, wires dependencies, and manages the lifecycle.

### Creating a Part

A **Part** is the primary unit of UI in an e4 application. It replaces the older View and Editor concepts from Eclipse 3.x.

```java
public class ContactListPart {

    private TableViewer viewer;

    @Inject
    private ContactService contactService;

    @PostConstruct
    public void createComposite(Composite parent) {
        viewer = new TableViewer(parent, SWT.BORDER | SWT.FULL_SELECTION);
        viewer.setContentProvider(ArrayContentProvider.getInstance());
        viewer.setLabelProvider(new ColumnLabelProvider() {
            @Override
            public String getText(Object element) {
                return ((Contact) element).getFullName();
            }
        });
        viewer.setInput(contactService.findAll());
    }

    @Focus
    public void setFocus() {
        viewer.getControl().setFocus();
    }
}
```

There is no interface to implement. The framework discovers the `@PostConstruct` method and injects the `Composite` parent and any declared services.

### Dependency Injection in e4

Eclipse e4 uses its own dependency injection framework based on **Eclipse Contexts**. Every UI element has an `IEclipseContext` that holds variables and services. Injection uses standard `@Inject` plus e4-specific annotations:

| Annotation | Purpose |
|---|---|
| `@Inject` | Inject a service or context value |
| `@PostConstruct` | Called after injection, used for initialization |
| `@PreDestroy` | Called before the part is destroyed |
| `@Focus` | Called when the part gains focus |
| `@Persist` | Called when the part needs to save its state |
| `@Optional` | Marks a dependency that may be absent |
| `@Named` | Qualifies the injection by name |

```java
@Inject
@Optional
public void onSelectionChanged(
        @Named(IServiceConstants.ACTIVE_SELECTION) Contact selected) {
    if (selected != null) {
        detailViewer.setInput(selected);
    }
}
```

The `@Optional` annotation prevents errors when no selection exists yet. The method is re-invoked automatically whenever the active selection changes.

## Commands and Handlers

Commands represent abstract operations. Handlers provide the implementation. This separation lets different plugins contribute handlers for the same command.

Define a command in the application model or via the `org.eclipse.ui.commands` extension point:

```xml
<extension point="org.eclipse.ui.commands">
    <command id="com.example.app.saveContact"
             name="Save Contact"
             description="Persists the current contact"/>
</extension>
```

Implement a handler:

```java
public class SaveContactHandler {

    @Execute
    public void execute(@Named(IServiceConstants.ACTIVE_SELECTION) Contact contact,
                        ContactService service) {
        service.save(contact);
    }

    @CanExecute
    public boolean canExecute(
            @Optional @Named(IServiceConstants.ACTIVE_SELECTION) Contact contact) {
        return contact != null && contact.isDirty();
    }
}
```

The `@CanExecute` method controls whether toolbar buttons and menu items are enabled or disabled.

## Services and OSGi Declarative Services

Business logic belongs in **services**, not in UI parts. In a well-structured RCP application, parts delegate to services which are registered as OSGi services.

Define a service interface:

```java
public interface ContactService {
    List<Contact> findAll();
    Contact findById(String id);
    void save(Contact contact);
    void delete(Contact contact);
}
```

Provide an implementation using **OSGi Declarative Services** (DS):

```java
@Component(service = ContactService.class)
public class ContactServiceImpl implements ContactService {

    @Reference
    private ContactRepository repository;

    @Override
    public List<Contact> findAll() {
        return repository.findAll();
    }

    @Override
    public void save(Contact contact) {
        repository.save(contact);
    }

    // ...remaining methods
}
```

DS annotations (`@Component`, `@Reference`, `@Activate`, `@Deactivate`) are processed at build time by the **bnd** tool, which generates XML descriptors. At runtime, the OSGi framework reads these descriptors and handles instantiation and wiring.

## Event System

The **IEventBroker** allows parts and services to communicate loosely via publish/subscribe.

```java
@Inject
private IEventBroker eventBroker;

public void notifyContactSaved(Contact contact) {
    eventBroker.post("contacts/saved", contact);
}
```

Subscribe in another part:

```java
@Inject
@Optional
public void onContactSaved(@UIEventTopic("contacts/saved") Contact contact) {
    viewer.refresh();
}
```

`@UIEventTopic` ensures the handler runs on the UI thread. Use `@EventTopic` when thread affinity is not required.

## Preferences and Persistence

Eclipse RCP provides a preferences framework that stores user settings per-scope (instance, configuration, default).

```java
IEclipsePreferences prefs = InstanceScope.INSTANCE.getNode("com.example.app");
prefs.put("lastOpenFile", "/home/user/data.csv");
prefs.flush();

String lastFile = prefs.get("lastOpenFile", "");
```

For richer structured data, consider using **EMF** (Eclipse Modeling Framework) or embedding an **H2 / SQLite** database within the application.

## Building and Packaging

### Maven Tycho

**Tycho** is a set of Maven plugins that understand OSGi manifests and Eclipse target platforms. A typical parent POM:

```xml
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>com.example.app.parent</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>

    <properties>
        <tycho.version>4.0.4</tycho.version>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <build>
        <plugins>
            <plugin>
                <groupId>org.eclipse.tycho</groupId>
                <artifactId>tycho-maven-plugin</artifactId>
                <version>${tycho.version}</version>
                <extensions>true</extensions>
            </plugin>
            <plugin>
                <groupId>org.eclipse.tycho</groupId>
                <artifactId>target-platform-configuration</artifactId>
                <version>${tycho.version}</version>
                <configuration>
                    <target>
                        <file>../releng/com.example.app.target/com.example.app.target.target</file>
                    </target>
                    <environments>
                        <environment>
                            <os>win32</os><ws>win32</ws><arch>x86_64</arch>
                        </environment>
                        <environment>
                            <os>linux</os><ws>gtk</ws><arch>x86_64</arch>
                        </environment>
                        <environment>
                            <os>macosx</os><ws>cocoa</ws><arch>x86_64</arch>
                        </environment>
                    </environments>
                </configuration>
            </plugin>
        </plugins>
    </build>

    <modules>
        <module>../bundles/com.example.app.core</module>
        <module>../bundles/com.example.app.ui</module>
        <module>../features/com.example.app.feature</module>
        <module>../releng/com.example.app.product</module>
    </modules>
</project>
```

Run `mvn clean verify` to build platform-specific archives for each configured environment.

### Product Configuration

A `.product` file describes the final deliverable: branding, splash screen, included features, JVM arguments, and launcher configuration.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?pde version="3.5"?>
<product name="My Application"
         uid="com.example.app.product"
         id="com.example.app.ui.product"
         application="org.eclipse.e4.ui.workbench.swt.E4Application"
         version="1.0.0.qualifier"
         type="features"
         includeLaunchers="true"
         autoIncludeRequirements="true">

    <configIni use="default"/>
    <launcherArgs>
        <vmArgsMac>-XstartOnFirstThread</vmArgsMac>
    </launcherArgs>

    <launcher name="myapp">
        <win useIco="true">
            <ico path="icons/app.ico"/>
        </win>
    </launcher>

    <features>
        <feature id="com.example.app.feature"/>
        <feature id="org.eclipse.e4.rcp"/>
    </features>
</product>
```

## Updating Applications with p2

Eclipse's **p2** provisioning system lets your application check for and install updates from a remote repository.

```java
@Execute
public void checkForUpdates(IProvisioningAgent agent) {
    IUpdateChecker checker = agent.getService(IUpdateChecker.class);
    checker.scheduleCheck(
        IUpdateChecker.ONE_TIME_CHECK,
        UpdateSearchParams.createDefaultParams(),
        new UpdateSearchResultCollector() {
            @Override
            public void accept(UpdateSearchResult result) {
                // present available updates to the user
            }
        }
    );
}
```

On the build side, Tycho can generate a **p2 repository** alongside your product. Host it on any HTTP server or use an Eclipse-specific repository manager.

## Testing

### SWTBot for UI Tests

**SWTBot** automates UI interactions for integration testing:

```java
@Test
public void shouldDisplayContactList() {
    SWTWorkbenchBot bot = new SWTWorkbenchBot();
    SWTBotView view = bot.viewByTitle("Contacts");
    view.show();

    SWTBotTable table = view.bot().table();
    assertThat(table.rowCount()).isGreaterThan(0);
    assertThat(table.cell(0, 0)).isEqualTo("Alice Johnson");
}
```

### Unit Testing Parts and Handlers

Because e4 parts are plain Java classes with injected dependencies, they are straightforward to unit test with mocking frameworks:

```java
@ExtendWith(MockitoExtension.class)
class SaveContactHandlerTest {

    @Mock
    private ContactService service;

    @InjectMocks
    private SaveContactHandler handler;

    @Test
    void shouldSaveContact() {
        Contact contact = new Contact("Alice");
        handler.execute(contact, service);
        verify(service).save(contact);
    }

    @Test
    void cannotExecuteWithoutSelection() {
        assertThat(handler.canExecute(null)).isFalse();
    }
}
```

## Project Structure

A well-organized Eclipse RCP workspace follows this convention:

```
com.example.app/
├── bundles/
│   ├── com.example.app.core/       # domain model and services
│   │   ├── META-INF/MANIFEST.MF
│   │   ├── OSGI-INF/               # DS component descriptors
│   │   └── src/
│   └── com.example.app.ui/         # parts, handlers, application model
│       ├── META-INF/MANIFEST.MF
│       ├── Application.e4xmi
│       ├── icons/
│       └── src/
├── features/
│   └── com.example.app.feature/    # groups bundles for distribution
│       └── feature.xml
├── releng/
│   ├── com.example.app.target/     # target platform definition
│   │   └── com.example.app.target.target
│   ├── com.example.app.product/    # product definition
│   │   └── com.example.app.product.product
│   └── pom.xml                     # parent POM with Tycho
└── tests/
    └── com.example.app.core.tests/ # fragment or bundle for tests
```

Separating **core** (domain logic, no UI dependencies) from **ui** (SWT/JFace, application model) keeps the architecture clean and makes the core testable without a display.

## Migrating from Eclipse 3.x to e4

Many existing RCP applications still use the Eclipse 3.x API (`IViewPart`, `IEditorPart`, `ActionDelegate`). Eclipse provides a **compatibility layer** that lets 3.x plugins run inside an e4 workbench, so migration can happen incrementally:

1. **Switch the product** to use `org.eclipse.e4.ui.workbench.swt.E4Application`.
2. Add `org.eclipse.ui.workbench` for the compatibility layer.
3. Existing 3.x views and editors continue to work.
4. New features are written as pure e4 parts.
5. Over time, convert 3.x contributions to e4, removing `plugin.xml` extension points in favor of the application model and annotations.

## Tips and Best Practices

- **Separate domain from UI.** Place models, services, and business logic in bundles that have no dependency on `org.eclipse.swt` or `org.eclipse.jface`.
- **Use Declarative Services over BundleActivators.** DS components are lazier, cleaner, and easier to test than activator-based code.
- **Favor the event broker for cross-part communication.** Direct references between parts create tight coupling and make reuse difficult.
- **Define a target platform early.** A reproducible target avoids "works on my machine" problems.
- **Run architecture tests.** Use ArchUnit or OSGi-level checks to enforce dependency rules between bundles.
- **Automate builds with Tycho and CI.** A single `mvn verify` should produce distributable archives for every platform.
- **Keep `Application.e4xmi` minimal.** Use model processors or fragments to contribute UI elements from separate plugins.

## Summary

Eclipse RCP provides a production-grade framework for building modular desktop applications in Java. Its layered architecture -- OSGi for modularity, SWT for native widgets, JFace for structured viewers, and the e4 application model for dependency injection and lifecycle management -- gives you a solid foundation that scales from small tools to large, plugin-based platforms.

The learning curve is steeper than Swing or JavaFX because of the OSGi layer and the tooling concepts (target platforms, features, products). But the payoff is significant: you get a plugin system, an update mechanism, cross-platform packaging, and a battle-tested runtime that powers Eclipse itself and hundreds of commercial products.

If you are building a desktop application that needs to be **extensible**, **modular**, and **professional-grade**, Eclipse RCP deserves a serious look.
