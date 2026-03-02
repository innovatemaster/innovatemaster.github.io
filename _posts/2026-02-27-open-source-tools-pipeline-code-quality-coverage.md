---
layout: post
title: "Open Source Tools for Code Quality and Coverage in Your Java/Spring CI/CD Pipeline"
date: 2026-02-27 20:00 +0100
categories: [DevOps, CI_CD]
tags: [ci-cd, code-quality, code-coverage, sonarqube, jacoco, owasp, spotbugs, java, spring-boot, maven, open-source, pipeline]
description: A practical guide to open source Maven plugins and tools you can integrate into any standard Java/Spring Boot CI/CD pipeline to enforce code quality, measure test coverage, verify architecture, detect vulnerabilities, and keep dependencies healthy.
---

# Open Source Tools for Code Quality and Coverage in Your Java/Spring CI/CD Pipeline

Every team has one -- the "0815" pipeline. It compiles the code, runs the tests, produces a JAR, and calls it a day. But a standard Maven or Gradle pipeline can become a **quality powerhouse** with the right open source tooling. This post surveys the most battle-tested open source plugins and tools you can drop into any Java/Spring Boot CI/CD system (Jenkins, GitLab CI, GitHub Actions, Azure DevOps, ...) to enforce code quality, measure coverage, verify architecture, catch security issues early, and keep your dependencies in check.

All tools are grouped by the problem they solve. For each tool you get a short description and a ready-to-use **Maven plugin configuration** so you can add it to your `pom.xml` right away.

---

## 1. Static Code Analysis

Static analysis reads your source code or bytecode **without executing it** and flags bugs, code smells, anti-patterns, and style violations. Catching these issues early prevents them from reaching code review -- or worse, production.

### SonarQube / SonarCloud

[SonarQube](https://www.sonarsource.com/open-source-editions/sonarqube-community-edition/) is the de-facto standard for continuous code quality inspection. The **Community Edition** is open source (LGPL-3.0) and has excellent Java and Kotlin support. SonarCloud is the SaaS variant, free for public repositories.

**What it checks:**

- Bugs, vulnerabilities, and security hotspots
- Code smells and maintainability issues
- Duplicated code blocks
- Cognitive and cyclomatic complexity
- Test coverage (imported from JaCoCo)
- Quality Gates that can **break the build** if thresholds are not met

**Maven integration:**

```xml
<!-- In your pom.xml properties -->
<properties>
  <sonar.projectKey>my-app</sonar.projectKey>
  <sonar.host.url>https://sonar.example.com</sonar.host.url>
  <sonar.coverage.jacoco.xmlReportPaths>
    ${project.build.directory}/site/jacoco/jacoco.xml
  </sonar.coverage.jacoco.xmlReportPaths>
</properties>
```

Run the analysis with:

```bash
./mvnw verify sonar:sonar -Dsonar.token=$SONAR_TOKEN
```

SonarQube picks up the JaCoCo coverage report automatically when configured via `sonar.coverage.jacoco.xmlReportPaths`. The `verify` phase runs your tests and generates coverage first, then `sonar:sonar` uploads everything.

> **Tip:** Configure a **Quality Gate** in SonarQube that requires, for example, >=80 % coverage on new code, zero new bugs, and zero new vulnerabilities. The scan step will fail the pipeline if the gate is not passed. This is the "Clean as You Code" approach -- you don't have to fix legacy code all at once, but every new commit must meet the bar.

### PMD

[PMD](https://pmd.github.io/) is a static source code analyzer that detects common programming flaws -- unused variables, empty catch blocks, unnecessary object creation, overly complex methods, and more. PMD also ships with **CPD** (Copy/Paste Detector) for finding duplicated code across your codebase.

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-pmd-plugin</artifactId>
  <version>3.26.0</version>
  <configuration>
    <rulesets>
      <ruleset>/category/java/bestpractices.xml</ruleset>
      <ruleset>/category/java/errorprone.xml</ruleset>
      <ruleset>/category/java/design.xml</ruleset>
      <ruleset>/category/java/performance.xml</ruleset>
    </rulesets>
    <failOnViolation>true</failOnViolation>
    <printFailingErrors>true</printFailingErrors>
    <linkXRef>false</linkXRef>
  </configuration>
  <executions>
    <execution>
      <goals>
        <goal>check</goal>
        <goal>cpd-check</goal>
      </goals>
    </execution>
  </executions>
</plugin>
```

The `cpd-check` goal runs the Copy/Paste Detector alongside the regular analysis. Both goals are bound to the `verify` phase by default.

### SpotBugs

[SpotBugs](https://spotbugs.github.io/) (the successor to FindBugs) analyzes Java **bytecode** to find real bugs -- null pointer dereferences, infinite recursive loops, resource leaks, and concurrency issues. Because it works on bytecode rather than source, it catches things that source-level tools miss.

```xml
<plugin>
  <groupId>com.github.spotbugs</groupId>
  <artifactId>spotbugs-maven-plugin</artifactId>
  <version>4.9.0.0</version>
  <configuration>
    <effort>Max</effort>
    <threshold>Medium</threshold>
    <failOnError>true</failOnError>
    <plugins>
      <plugin>
        <groupId>com.h3xstream.findsecbugs</groupId>
        <artifactId>findsecbugs-plugin</artifactId>
        <version>1.13.0</version>
      </plugin>
    </plugins>
  </configuration>
  <executions>
    <execution>
      <goals><goal>check</goal></goals>
    </execution>
  </executions>
</plugin>
```

Note the embedded **Find Security Bugs** plugin. This extends SpotBugs with over 150 security-focused bug patterns -- SQL injection, XSS, path traversal, weak cryptography, insecure deserialization, and Spring-specific issues like unvalidated redirects and exposed actuator endpoints. Adding this single dependency turns SpotBugs into a lightweight SAST tool for your Java code.

### Checkstyle

[Checkstyle](https://checkstyle.org/) enforces coding standards for Java. It verifies that your code adheres to a defined style guide (Google Java Style, Sun Conventions, or your own). Consistent style across a team reduces cognitive load during reviews.

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-checkstyle-plugin</artifactId>
  <version>3.6.0</version>
  <configuration>
    <configLocation>google_checks.xml</configLocation>
    <consoleOutput>true</consoleOutput>
    <failOnViolation>true</failOnViolation>
    <violationSeverity>warning</violationSeverity>
  </configuration>
  <executions>
    <execution>
      <goals><goal>check</goal></goals>
    </execution>
  </executions>
</plugin>
```

Checkstyle ships with `google_checks.xml` and `sun_checks.xml` built in. For most teams, starting with Google's style and customizing a few rules (line length, import order) is the fastest path to consistency.

---

## 2. Code Coverage

Test coverage tools measure which lines, branches, and conditions of your code are exercised by your test suite. Coverage alone does not guarantee quality, but it highlights **untested** areas that deserve attention.

### JaCoCo

[JaCoCo](https://www.jacoco.org/jacoco/) is the standard code coverage library for Java. It instruments bytecode on the fly and produces reports in HTML, XML, and CSV. SonarQube, GitLab CI, and most other CI systems can consume its XML reports directly.

```xml
<plugin>
  <groupId>org.jacoco</groupId>
  <artifactId>jacoco-maven-plugin</artifactId>
  <version>0.8.12</version>
  <executions>
    <execution>
      <id>prepare-agent</id>
      <goals><goal>prepare-agent</goal></goals>
    </execution>
    <execution>
      <id>report</id>
      <phase>verify</phase>
      <goals><goal>report</goal></goals>
    </execution>
    <execution>
      <id>check</id>
      <phase>verify</phase>
      <goals><goal>check</goal></goals>
      <configuration>
        <rules>
          <rule>
            <element>BUNDLE</element>
            <limits>
              <limit>
                <counter>LINE</counter>
                <value>COVEREDRATIO</value>
                <minimum>0.80</minimum>
              </limit>
              <limit>
                <counter>BRANCH</counter>
                <value>COVEREDRATIO</value>
                <minimum>0.70</minimum>
              </limit>
            </limits>
          </rule>
        </rules>
      </configuration>
    </execution>
  </executions>
</plugin>
```

Three executions work together:

1. **prepare-agent** -- attaches the JaCoCo agent to the JVM that runs your tests (Surefire / Failsafe).
2. **report** -- generates the HTML and XML reports from the recorded execution data.
3. **check** -- **breaks the build** if coverage drops below the configured thresholds (80 % line, 70 % branch in this example).

**Excluding generated code:** Spring Boot applications often contain generated classes (Lombok, MapStruct, configuration properties). Exclude them so they don't distort your metrics:

```xml
<configuration>
  <excludes>
    <exclude>**/generated/**</exclude>
    <exclude>**/*MapperImpl.class</exclude>
    <exclude>**/*Application.class</exclude>
  </excludes>
</configuration>
```

### Cobertura Reports for MR Annotations

Many CI platforms (GitLab CI, Azure DevOps, GitHub Actions via third-party actions) can render **Cobertura XML** reports as merge request annotations, showing exactly which lines in a pull request are uncovered. JaCoCo's XML output is compatible:

```yaml
# GitLab CI example
test:
  stage: test
  script:
    - ./mvnw verify
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: target/site/jacoco/jacoco.xml
```

---

## 3. Architecture Verification

In a Spring Boot application, architectural rules -- "controllers must not access repositories directly", "no circular module dependencies" -- are easy to state but hard to enforce. These tools make the rules executable.

### ArchUnit

[ArchUnit](https://www.archunit.org/) is a Java library for testing architectural constraints as plain JUnit tests. No special tooling, no agents -- just add the dependency and write test classes.

```xml
<dependency>
  <groupId>com.tngtech.archunit</groupId>
  <artifactId>archunit-junit5</artifactId>
  <version>1.3.0</version>
  <scope>test</scope>
</dependency>
```

Example rules for a Spring Boot application:

```java
@AnalyzeClasses(packages = "com.example.myapp")
class ArchitectureTest {

    @ArchTest
    static final ArchRule controllers_should_not_access_repositories =
        noClasses()
            .that().resideInAPackage("..controller..")
            .should().accessClassesThat()
            .resideInAPackage("..repository..");

    @ArchTest
    static final ArchRule services_should_only_be_accessed_by_controllers_or_other_services =
        classes()
            .that().resideInAPackage("..service..")
            .should().onlyBeAccessed()
            .byAnyPackage("..controller..", "..service..");

    @ArchTest
    static final ArchRule no_cycles_between_packages =
        slices().matching("com.example.myapp.(*)..")
            .should().beFreeOfCycles();

    @ArchTest
    static final ArchRule spring_annotations_on_correct_layers =
        noClasses()
            .that().areAnnotatedWith(RestController.class)
            .should().resideInAPackage("..service..");
}
```

Because these are regular JUnit tests, they run in your normal `mvn test` phase and fail the build on violations -- no extra pipeline configuration needed.

### Spring Modulith

If you use [Spring Modulith](https://spring.io/projects/spring-modulith), you get **built-in architecture verification** that understands Spring's component model. It detects circular dependencies between application modules and enforces that internal module classes are not accessed from outside.

```xml
<dependency>
  <groupId>org.springframework.modulith</groupId>
  <artifactId>spring-modulith-starter-test</artifactId>
  <scope>test</scope>
</dependency>
```

```java
class ModulithArchitectureTest {

    @Test
    void verifyModularStructure() {
        ApplicationModules.of(MyApplication.class).verify();
    }
}
```

This single call checks all module boundaries, detects circular dependencies, and ensures no module reaches into another module's internal packages. It pairs naturally with ArchUnit for more fine-grained rules.

---

## 4. Security Scanning

Shifting security **left** means catching vulnerabilities during development, not after deployment. These tools fit neatly into any Maven-based pipeline.

### OWASP Dependency-Check

[OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/) scans your project dependencies against the **National Vulnerability Database (NVD)** and reports known CVEs. For a Spring Boot project with dozens of transitive dependencies, this is essential.

```xml
<plugin>
  <groupId>org.owasp</groupId>
  <artifactId>dependency-check-maven</artifactId>
  <version>11.1.1</version>
  <configuration>
    <failBuildOnCVSS>7</failBuildOnCVSS>
    <formats>
      <format>HTML</format>
      <format>JSON</format>
    </formats>
    <suppressionFile>owasp-suppressions.xml</suppressionFile>
  </configuration>
  <executions>
    <execution>
      <goals><goal>check</goal></goals>
    </execution>
  </executions>
</plugin>
```

With `failBuildOnCVSS` set to 7, any dependency with a CVSS score of 7 or higher (High/Critical) will break the build. The `suppressionFile` lets you acknowledge false positives or accepted risks without disabling the entire check.

### SpotBugs + Find Security Bugs (SAST)

As shown in the Static Analysis section, adding the **Find Security Bugs** plugin to SpotBugs gives you lightweight SAST for Java. It catches Spring-specific security issues:

- Unvalidated redirect/forward via Spring MVC
- SpEL injection
- Exposed Spring Boot Actuator endpoints
- Insecure `@CrossOrigin` configurations
- SQL injection in Spring JDBC / JPA queries
- Insecure deserialization patterns

This runs as part of your normal `spotbugs:check` goal -- no separate scan needed.

### Trivy

[Trivy](https://trivy.dev/) by Aqua Security is a comprehensive vulnerability scanner. While it is language-agnostic, it understands `pom.xml` and `build.gradle` files and can scan:

- **Filesystems** for dependency vulnerabilities in your Maven/Gradle project
- **Container images** for OS-level and application vulnerabilities in your Spring Boot Docker image
- **IaC files** (Kubernetes manifests, Helm charts) for misconfigurations

```yaml
# GitHub Actions -- scan the project filesystem
- name: Trivy dependency scan
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: fs
    scan-ref: .
    severity: CRITICAL,HIGH
    exit-code: 1

# Scan the built Docker image
- name: Trivy image scan
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: myapp:latest
    severity: CRITICAL,HIGH
    exit-code: 1
```

### Gitleaks

[Gitleaks](https://gitleaks.io/) detects **hardcoded secrets** -- API keys, database passwords, JWT signing keys, private keys -- in your Git repository. Especially relevant for Spring Boot projects where `application.yml` or `application.properties` might accidentally contain real credentials.

```yaml
- name: Gitleaks
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 5. Code Formatting

Automated formatting eliminates style debates in code review and ensures a consistent codebase. Run formatters in CI as a **check** (verify mode) to reject unformatted code.

### Spotless

[Spotless](https://github.com/diffplug/spotless) is a versatile formatting plugin for Maven and Gradle. It can enforce formatting for Java, Kotlin, XML, Markdown, and more. Under the hood it delegates to formatters like google-java-format, eclipse-jdt, or palantir-java-format.

```xml
<plugin>
  <groupId>com.diffplug.spotless</groupId>
  <artifactId>spotless-maven-plugin</artifactId>
  <version>2.44.3</version>
  <configuration>
    <java>
      <googleJavaFormat>
        <version>1.25.2</version>
        <style>AOSP</style>
      </googleJavaFormat>
      <removeUnusedImports/>
      <importOrder>
        <order>java,javax,org,com</order>
      </importOrder>
    </java>
    <pom>
      <sortPom>
        <expandEmptyElements>false</expandEmptyElements>
      </sortPom>
    </pom>
  </configuration>
  <executions>
    <execution>
      <goals><goal>check</goal></goals>
    </execution>
  </executions>
</plugin>
```

Run `./mvnw spotless:check` in CI to fail on unformatted code, or `./mvnw spotless:apply` locally to auto-fix.

### google-java-format

[google-java-format](https://github.com/google/google-java-format) is the standalone formatter behind Spotless's Java support. If you prefer to run it directly (e.g., as a pre-commit hook or IDE plugin), it reformats Java source code to comply with Google Java Style:

```bash
java -jar google-java-format-1.25.2-all-deps.jar \
  --dry-run --set-exit-if-changed \
  $(find src -name "*.java")
```

---

## 6. Build Guardrails

### Maven Enforcer Plugin

The [Maven Enforcer Plugin](https://maven.apache.org/enforcer/maven-enforcer-plugin/) adds build-time rules that prevent common problems before any code analysis even runs.

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-enforcer-plugin</artifactId>
  <version>3.5.0</version>
  <executions>
    <execution>
      <id>enforce</id>
      <goals><goal>enforce</goal></goals>
      <configuration>
        <rules>
          <requireMavenVersion>
            <version>[3.9.0,)</version>
          </requireMavenVersion>
          <requireJavaVersion>
            <version>[21,)</version>
          </requireJavaVersion>
          <banDuplicatePomDependencyVersions/>
          <dependencyConvergence/>
          <banDistributionManagement/>
        </rules>
      </configuration>
    </execution>
  </executions>
</plugin>
```

Key rules explained:

| Rule | What it prevents |
|---|---|
| `requireMavenVersion` | Builds with an unsupported Maven version |
| `requireJavaVersion` | Builds with the wrong JDK |
| `banDuplicatePomDependencyVersions` | Same dependency declared twice with different versions |
| `dependencyConvergence` | Transitive dependencies resolving to conflicting versions |
| `banDistributionManagement` | Child POMs overriding distribution management from the parent |

### Versions Maven Plugin

The [Versions Maven Plugin](https://www.mojohaus.org/versions/versions-maven-plugin/) helps you detect outdated dependencies and plugin versions. While it doesn't auto-update like Renovate, it is useful as a pipeline reporting step:

```bash
./mvnw versions:display-dependency-updates
./mvnw versions:display-plugin-updates
```

---

## 7. Dependency Management and Updates

Outdated dependencies are one of the top sources of vulnerabilities. Automated dependency update tools create pull requests when new versions are available.

### Renovate

[Renovate](https://docs.renovatebot.com/) is a highly configurable open source bot that understands Maven, Gradle, Docker, Helm, and dozens more ecosystems. It creates PRs with changelogs, respects semver, groups related updates, and can auto-merge patch updates.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    ":automergeMinor",
    "group:allNonMajor"
  ],
  "packageRules": [
    {
      "matchManagers": ["maven"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true
    },
    {
      "matchPackagePatterns": ["^org.springframework"],
      "groupName": "Spring Framework"
    }
  ],
  "vulnerabilityAlerts": {
    "enabled": true
  }
}
```

This configuration groups all Spring Framework updates into a single PR and auto-merges minor/patch Maven updates when all pipeline checks pass.

### Dependabot

[Dependabot](https://docs.github.com/en/code-security/dependabot) is GitHub's built-in dependency update service, free and deeply integrated into GitHub.

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: maven
    directory: /
    schedule:
      interval: weekly
    groups:
      spring:
        patterns:
          - "org.springframework*"
  - package-ecosystem: docker
    directory: /
    schedule:
      interval: monthly
```

---

## 8. Mutation Testing

Code coverage tells you which lines are executed, but not whether your tests actually **verify** the correctness of those lines. Mutation testing deliberately introduces small changes (mutations) -- like replacing `>` with `>=` or `true` with `false` -- and checks if any test fails. If a mutation survives (no test catches it), your test suite has a gap.

### PIT (Pitest)

[PIT](https://pitest.org/) is the leading mutation testing tool for Java. It modifies bytecode at runtime and runs your tests against each mutant. The `pitest-junit5-plugin` adds JUnit 5 support.

```xml
<plugin>
  <groupId>org.pitest</groupId>
  <artifactId>pitest-maven</artifactId>
  <version>1.17.4</version>
  <dependencies>
    <dependency>
      <groupId>org.pitest</groupId>
      <artifactId>pitest-junit5-plugin</artifactId>
      <version>1.2.1</version>
    </dependency>
  </dependencies>
  <configuration>
    <targetClasses>
      <param>com.example.myapp.*</param>
    </targetClasses>
    <targetTests>
      <param>com.example.myapp.*</param>
    </targetTests>
    <mutationThreshold>60</mutationThreshold>
    <timestampedReports>false</timestampedReports>
    <excludedClasses>
      <param>com.example.myapp.config.*</param>
      <param>com.example.myapp.*Application</param>
    </excludedClasses>
  </configuration>
</plugin>
```

Run with `./mvnw pitest:mutationCoverage`. The HTML report shows exactly which mutations survived and which test should have caught them.

> **Tip:** Mutation testing is computationally expensive. Run it on a **nightly or weekly schedule** rather than on every pull request. Focus on your domain/service layer where the business logic lives, and exclude configuration classes and generated code.

---

## 9. License Compliance

When shipping software, you need to know what licenses your dependencies use. This is especially important in enterprise contexts where GPL or AGPL licenses may be incompatible with your distribution model.

### License Maven Plugin

The [License Maven Plugin](https://www.mojohaus.org/license-maven-plugin/) by MojoHaus scans all dependencies and produces a license inventory. It can also fail the build on disallowed licenses.

```xml
<plugin>
  <groupId>org.codehaus.mojo</groupId>
  <artifactId>license-maven-plugin</artifactId>
  <version>2.4.0</version>
  <executions>
    <execution>
      <id>add-third-party</id>
      <goals><goal>add-third-party</goal></goals>
      <configuration>
        <failOnMissing>true</failOnMissing>
        <excludedLicenses>
          <excludedLicense>GNU General Public License v3.0</excludedLicense>
          <excludedLicense>GNU Affero General Public License v3.0</excludedLicense>
        </excludedLicenses>
        <failOnBlacklist>true</failOnBlacklist>
      </configuration>
    </execution>
  </executions>
</plugin>
```

---

## 10. Putting It All Together -- A Reference Pipeline

Here is a stage-by-stage view of how these tools compose into a complete quality pipeline for a Spring Boot application. The stages are ordered by **feedback speed** -- fast checks first, slow checks last.

```
┌──────────────────────────────────────────────────────────────────┐
│  Stage 1: Build Guardrails  (seconds)                            │
│  ┌──────────────────┐  ┌────────────┐  ┌────────────────────┐   │
│  │ Maven Enforcer   │  │ Spotless   │  │   Checkstyle       │   │
│  └──────────────────┘  └────────────┘  └────────────────────┘   │
├──────────────────────────────────────────────────────────────────┤
│  Stage 2: Build & Unit Test + Coverage  (minutes)                │
│  ┌──────────────┐  ┌─────────┐  ┌───────────────────────────┐  │
│  │   JaCoCo     │  │ JUnit 5 │  │   ArchUnit / Modulith     │  │
│  └──────────────┘  └─────────┘  └───────────────────────────┘  │
├──────────────────────────────────────────────────────────────────┤
│  Stage 3: Static Analysis & SAST  (minutes)                      │
│  ┌────────────┐  ┌──────────┐  ┌──────────────────────────┐    │
│  │ SonarQube  │  │   PMD    │  │ SpotBugs + FindSecBugs   │    │
│  └────────────┘  └──────────┘  └──────────────────────────┘    │
├──────────────────────────────────────────────────────────────────┤
│  Stage 4: Dependency & Container Scanning  (minutes)             │
│  ┌──────────────────┐  ┌──────────┐  ┌──────────┐              │
│  │ OWASP Dep-Check  │  │  Trivy   │  │ Gitleaks │              │
│  └──────────────────┘  └──────────┘  └──────────┘              │
├──────────────────────────────────────────────────────────────────┤
│  Stage 5: Quality Gate Decision                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  SonarQube Quality Gate  /  JaCoCo check  /  fail rules  │   │
│  └──────────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────────┤
│  Stage 6: Nightly -- Mutation Testing & License Scan             │
│  ┌──────────┐  ┌──────────────────────┐                         │
│  │   PIT    │  │ License Maven Plugin │                         │
│  └──────────┘  └──────────────────────┘                         │
└──────────────────────────────────────────────────────────────────┘
```

### Complete GitHub Actions Workflow

```yaml
name: Spring Boot Quality Pipeline

on:
  push:
    branches: [main]
  pull_request:

env:
  JAVA_VERSION: 21

jobs:
  format-and-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: ${{ env.JAVA_VERSION }}
          cache: maven
      - name: Spotless format check
        run: ./mvnw spotless:check
      - name: Checkstyle
        run: ./mvnw checkstyle:check
      - name: Maven Enforcer
        run: ./mvnw enforcer:enforce

  build-and-test:
    runs-on: ubuntu-latest
    needs: format-and-lint
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: ${{ env.JAVA_VERSION }}
          cache: maven
      - name: Build, test, coverage, architecture
        run: ./mvnw verify
      - name: Upload JaCoCo report
        uses: actions/upload-artifact@v4
        with:
          name: jacoco-report
          path: target/site/jacoco/

  static-analysis:
    runs-on: ubuntu-latest
    needs: build-and-test
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: ${{ env.JAVA_VERSION }}
          cache: maven
      - name: PMD
        run: ./mvnw pmd:check
      - name: SpotBugs + FindSecBugs
        run: ./mvnw spotbugs:check
      - name: SonarQube Scan
        run: ./mvnw verify sonar:sonar -Dsonar.token=${{ secrets.SONAR_TOKEN }}
        env:
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}

  security:
    runs-on: ubuntu-latest
    needs: build-and-test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: ${{ env.JAVA_VERSION }}
          cache: maven
      - name: Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: OWASP Dependency-Check
        run: ./mvnw dependency-check:check
      - name: Trivy filesystem scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: fs
          severity: CRITICAL,HIGH
          exit-code: 1
```

---

## Quick Reference: All Plugins at a Glance

| Problem Domain | Tool | Maven Plugin / Dependency | Fails Build? |
|---|---|---|---|
| **Style / Formatting** | Spotless | `com.diffplug.spotless:spotless-maven-plugin` | Yes |
| **Style / Conventions** | Checkstyle | `maven-checkstyle-plugin` | Yes |
| **Static Analysis** | PMD + CPD | `maven-pmd-plugin` | Yes |
| **Bug Detection** | SpotBugs | `spotbugs-maven-plugin` | Yes |
| **Security (SAST)** | Find Security Bugs | SpotBugs plugin: `findsecbugs-plugin` | Yes |
| **Security (Dependencies)** | OWASP Dep-Check | `dependency-check-maven` | Yes (CVSS threshold) |
| **Security (Containers)** | Trivy | CLI / GitHub Action | Yes |
| **Secret Detection** | Gitleaks | CLI / GitHub Action | Yes |
| **Code Coverage** | JaCoCo | `jacoco-maven-plugin` | Yes (threshold) |
| **Quality Gate** | SonarQube | `sonar-maven-plugin` | Yes (gate) |
| **Architecture** | ArchUnit | `archunit-junit5` (test dep) | Yes (test failure) |
| **Architecture** | Spring Modulith | `spring-modulith-starter-test` (test dep) | Yes (test failure) |
| **Build Guardrails** | Maven Enforcer | `maven-enforcer-plugin` | Yes |
| **Mutation Testing** | PIT | `pitest-maven` | Yes (threshold) |
| **License Compliance** | License Maven Plugin | `license-maven-plugin` | Yes |
| **Dependency Updates** | Renovate / Dependabot | Config file (not a Maven plugin) | N/A (creates PRs) |

---

## Best Practices

1. **Fail fast.** Run the cheapest checks first (formatting, enforcer, checkstyle) so developers get feedback in seconds, not minutes.
2. **Enforce thresholds on new code.** Requiring 80 % coverage on the entire project is painful to retrofit. Requiring 80 % on *new code* (SonarQube's "Clean as You Code" approach) is achievable and steadily improves the codebase.
3. **Use Quality Gates.** A pipeline that reports problems but never blocks merges is just noise. Make the gates strict on critical issues (bugs, vulnerabilities, secrets) and advisory on style.
4. **Pin your plugin versions.** A surprise rule update in PMD or Checkstyle can break dozens of builds. Pin versions in your parent POM and update deliberately.
5. **Keep scan results visible.** Publish JaCoCo reports as PR annotations (via Cobertura format), not just as downloadable artifacts buried in the build log.
6. **Automate dependency updates.** Renovate or Dependabot PRs with passing pipelines can be auto-merged for patch versions, drastically reducing the maintenance burden.
7. **Run mutation testing on a schedule.** PIT is too slow for every PR. Run it nightly or weekly and review the results periodically to strengthen your test suite where it matters most -- in the domain layer.
8. **Centralize plugin configuration.** Use a parent POM or `pluginManagement` section to define tool versions and configurations once. Child modules inherit the rules without duplication.

---

## Conclusion

You do not need expensive commercial tooling to build a world-class quality pipeline for your Spring Boot application. The Maven plugin ecosystem alone provides mature, well-maintained tools for every aspect -- from formatting and linting to coverage, architecture verification, security scanning, and mutation testing. Start with the basics (Checkstyle + JaCoCo + OWASP Dependency-Check), enforce them with SonarQube quality gates, and expand gradually. Your future self -- debugging a production incident at 2 AM -- will thank you.
