---
layout: post
title: "Buildpacks: From Source Code to Container Image Without a Dockerfile"
date: 2026-02-27 20:00 +0100
categories: [DevOps, Containers]
tags: [buildpacks, docker, containers, cloud-native, paketo, ci-cd, cncf]
description: Buildpacks transform your application source code into production-ready container images without requiring a Dockerfile. Learn what they are, how to use them with pack CLI and Spring Boot Maven plugin, and best practices for production workflows.
---

# Buildpacks: From Source Code to Container Image Without a Dockerfile

Every containerized application needs an image, and for most teams that means writing and maintaining a Dockerfile. But Dockerfiles are essentially shell scripts with a build context -- they give you total freedom, which also means total responsibility for layer caching, security patching, minimal base images, and reproducibility. **Cloud Native Buildpacks** (CNB) offer a different model: hand your source code to a builder and get back a secure, efficient, OCI-compliant container image -- no Dockerfile required.

Buildpacks are a [CNCF incubating project](https://www.cncf.io/projects/buildpacks/) used in production by Heroku, Google Cloud Run, GitLab Auto DevOps, and many others. The most widely adopted implementation for the broader community is the [Paketo Buildpacks](https://paketo.io) project.

## How Buildpacks Work

A buildpack is a unit of work that inspects your source code and, if it recognizes the language or framework, contributes dependencies, configuration, and a launch process to the final image. The high-level flow looks like this:

```
┌──────────────┐      ┌───────────┐      ┌────────────────┐
│  Source Code  │─────▶│  Builder  │─────▶│  OCI Image     │
│  (no Docker-  │      │ (stack +  │      │  (runnable      │
│   file needed)│      │ buildpacks│      │   container)    │
└──────────────┘      └───────────┘      └────────────────┘
```

The builder is a special image that bundles:

1. **Build image** -- the OS layer used during the build phase (compilers, package managers).
2. **Run image** -- the minimal OS layer included in the final image (no compilers, no build tools).
3. **Buildpacks** -- ordered sets of detect/build scripts that know how to handle specific languages.
4. **Lifecycle** -- the CNB binary that orchestrates detection, build, export, and caching.

### The Lifecycle in Detail

The lifecycle runs through several phases:

| Phase        | What Happens                                                                 |
|:-------------|:-----------------------------------------------------------------------------|
| **Detect**   | Each buildpack checks if it applies (e.g., "is there a `pom.xml`?"). Only matching buildpacks proceed. |
| **Analyze**  | Restores metadata from previous builds for layer reuse.                      |
| **Restore**  | Pulls cached layers from the previous image so unchanged dependencies are not rebuilt. |
| **Build**    | Each selected buildpack runs in order -- downloading dependencies, compiling code, setting env vars. |
| **Export**    | Layers are assembled into a final OCI image and pushed to a registry or loaded into the local Docker daemon. |

Because each dependency lives in its own **layer**, a small code change does not trigger a full rebuild. Maven dependencies, for example, get their own cached layer and are only re-downloaded when `pom.xml` changes. This is one of the biggest practical advantages over naive Dockerfiles.

## Getting Started with `pack` CLI

The primary developer tool for buildpacks is [`pack`](https://buildpacks.io/docs/install-pack/), a CLI maintained by the CNB project.

### Installation

```shell
# macOS
brew install buildpacks/tap/pack

# Windows (Scoop)
scoop install pack

# Linux
sudo add-apt-repository ppa:cncf-buildpacks/pack-cli
sudo apt-get update
sudo apt-get install pack-cli
```

### Building Your First Image

Given a Java project with a `pom.xml` at the repository root:

```shell
pack build my-app --builder paketobuildpacks/builder-jammy-base
```

That single command:

1. Pulls the Paketo Jammy base builder (Ubuntu 22.04-based).
2. Detects that the project is a Maven Java app.
3. Downloads and caches the JDK, Maven, and project dependencies.
4. Compiles the application.
5. Selects an appropriate JRE for the run image.
6. Produces a runnable OCI image tagged `my-app:latest`.

Run it the usual way:

```shell
docker run --rm -p 8080:8080 my-app
```

### Choosing a Builder

Paketo provides several builders targeting different stacks:

| Builder                                    | Base OS          | Use Case                        |
|:-------------------------------------------|:-----------------|:--------------------------------|
| `paketobuildpacks/builder-jammy-base`      | Ubuntu 22.04     | General purpose, most languages |
| `paketobuildpacks/builder-jammy-full`      | Ubuntu 22.04     | Includes more system libraries  |
| `paketobuildpacks/builder-jammy-tiny`      | Ubuntu 22.04     | Minimal footprint for Java, Go  |
| `paketobuildpacks/builder-jammy-static`    | Distroless       | Statically compiled binaries    |

Set a default builder so you don't have to specify it every time:

```shell
pack config default-builder paketobuildpacks/builder-jammy-base
```

## Spring Boot Integration

Spring Boot has first-class buildpack support built into the `spring-boot-maven-plugin` -- you don't even need `pack` installed.

```shell
./mvnw spring-boot:build-image -Dspring-boot.build-image.imageName=my-spring-app
```

Under the hood this invokes the Paketo Java buildpack, which handles JDK selection, dependency caching, memory calculation (via the Cloud Native Buildpacks Memory Calculator), and CDS/AOT optimizations when available.

You can customize buildpack behavior through `pom.xml`:

```xml
<plugin>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-maven-plugin</artifactId>
    <configuration>
        <image>
            <name>registry.example.com/${project.artifactId}:${project.version}</name>
            <env>
                <BP_JVM_VERSION>21</BP_JVM_VERSION>
                <BP_MAVEN_ACTIVE_PROFILES>production</BP_MAVEN_ACTIVE_PROFILES>
            </env>
        </image>
    </configuration>
</plugin>
```

## Configuration via Environment Variables

Buildpacks are configured almost entirely through **environment variables** prefixed with `BP_` (build-time) and `BPL_` (launch-time). This avoids the need for configuration files and makes CI/CD integration straightforward.

Common examples for Java / Spring Boot:

```shell
# Select JVM version
pack build my-app --env BP_JVM_VERSION=21

# Enable debug on launch
docker run --rm -e BPL_DEBUG_ENABLED=true -e BPL_DEBUG_PORT=5005 -p 5005:5005 -p 8080:8080 my-app

# Build a native image with GraalVM
pack build my-app --env BP_NATIVE_IMAGE=true

# Activate a Maven profile
pack build my-app --env BP_MAVEN_ACTIVE_PROFILES=production

# Add custom CA certificates at build time
pack build my-app --env BP_EMBED_CERTS=true --volume /path/to/certs:/platform/bindings/ca-certificates
```

## Rebasing -- Patching Without Rebuilding

One of the most powerful features of buildpacks is **rebase**. Because the application layers and the OS layers are separate, you can swap the run image (OS + system libraries) without rebuilding the application. This means security patches to the base OS can be applied in seconds, not minutes.

```shell
pack rebase my-app
```

This pulls the latest version of the run image and re-assembles the final image with the same application layers. No source code, compiler, or build tool is needed.

## Integrating with CI/CD

### GitHub Actions

```yaml
name: Build with Buildpacks

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up pack CLI
        uses: buildpacks/github-actions/setup-pack@v5.7.4

      - name: Build image
        run: |
          pack build ghcr.io/${{ github.repository }}:${{ github.sha }} \
            --builder paketobuildpacks/builder-jammy-base \
            --publish
        env:
          DOCKER_LOGIN: ${{ secrets.GHCR_USER }}
          DOCKER_PASSWORD: ${{ secrets.GHCR_TOKEN }}
```

### GitLab CI

GitLab Auto DevOps uses buildpacks by default. For manual configuration:

```yaml
build:
  image: paketobuildpacks/builder-jammy-base
  script:
    - pack build $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
        --builder paketobuildpacks/builder-jammy-base
        --publish
```

### Spring Boot Maven Plugin in CI

For Spring Boot projects, you can skip `pack` entirely and use the Maven plugin:

```yaml
- name: Build container image
  run: ./mvnw spring-boot:build-image
    -Dspring-boot.build-image.imageName=ghcr.io/${{ github.repository }}:${{ github.sha }}
    -Dspring-boot.build-image.publish=true
```

## Best Practices

### 1. Pin Your Builder Version

Builders are updated frequently. In CI pipelines, pin the builder image by digest or tag to get reproducible builds.

```shell
pack build my-app --builder paketobuildpacks/builder-jammy-base:0.4.305
```

In Spring Boot:

```xml
<image>
    <builder>paketobuildpacks/builder-jammy-base:0.4.305</builder>
</image>
```

### 2. Use the Smallest Appropriate Builder

Start with `builder-jammy-tiny` for Java applications when possible. Fall back to `base` or `full` only if you need additional system libraries. Smaller builders mean smaller images, faster pulls, and a reduced attack surface.

### 3. Leverage Layer Caching

Buildpacks cache dependencies in separate layers by design. To get the most from this:

- Keep your `pom.xml` stable when only application code changes.
- In CI, use `--cache-image` to persist cache layers in a registry so that every pipeline run benefits from previous builds.

```shell
pack build my-app \
  --cache-image registry.example.com/my-app-cache \
  --publish
```

### 4. Use Bindings for Secrets and Certificates

Never bake secrets into the image. Buildpacks support **bindings** -- mounted volumes that provide credentials, certificates, or configuration at build or launch time.

```shell
pack build my-app \
  --volume /path/to/binding:/platform/bindings/my-binding
```

A binding directory contains a `type` file and one or more value files. For example, a CA certificate binding:

```
my-ca-cert/
├── type         # contains: ca-certificates
└── ca.pem       # the certificate file
```

### 5. Automate Rebase for OS Patches

Set up a scheduled CI job that runs `pack rebase` against your production images whenever the run image is updated. This applies OS-level security patches without touching application code, and it completes in seconds.

### 6. Use a Bill of Materials (SBOM)

Buildpacks generate a **Software Bill of Materials** automatically. Inspect it with:

```shell
pack sbom download my-app --output-dir ./sbom
```

Feed the SBOM into vulnerability scanners (Trivy, Grype, Snyk) for continuous security monitoring.

### 7. Set Memory Limits Explicitly

The Paketo Java buildpack includes a **memory calculator** that auto-tunes JVM heap, metaspace, and thread stack sizes based on the container's memory limit. Always set a memory limit on your container so the calculator can do its job:

```shell
docker run --rm -m 512m -p 8080:8080 my-app
```

### 8. Keep Build and Run Concerns Separate

Avoid adding build-only dependencies to the run image. Buildpacks handle this automatically (compilers and build tools only exist in the build image), but if you add custom buildpacks, make sure build-phase layers are marked `build = true` and not `launch = true`.

### 9. Test Locally Before CI

Run `pack build` locally during development to catch issues early. The same builder and buildpacks that run in CI will produce the same image on your laptop, giving you confidence that the pipeline will succeed.

### 10. Prefer Buildpacks Over Multi-Stage Dockerfiles

If your Dockerfile follows the pattern of "install build tools, copy source, build, then copy artifacts to a slim runtime image," a buildpack already does this -- with better caching, automatic security patching via rebase, and zero maintenance of the Dockerfile itself. Reserve Dockerfiles for cases where you need very specific system-level customization that no buildpack supports.

## Buildpacks vs. Dockerfiles -- When to Use Which

| Criteria                     | Buildpacks                          | Dockerfile                          |
|:-----------------------------|:------------------------------------|:------------------------------------|
| **Setup effort**             | Minimal -- just run `pack build`    | Must write and maintain Dockerfile  |
| **Reproducibility**          | High -- deterministic builds        | Varies with base image updates      |
| **Security patching**        | `rebase` swaps OS in seconds        | Rebuild entire image                |
| **Caching**                  | Automatic, layer-granular           | Manual with `COPY --from` stages    |
| **Customization**            | Via env vars and bindings           | Full shell-level control            |
| **Ecosystem support**        | Java, Node, Go, Python, .NET, etc. | Anything with a shell               |
| **SBOM generation**          | Built-in                            | Requires additional tooling         |
| **Learning curve**           | Low for supported languages         | Low but error-prone at scale        |

Use buildpacks when your language is well-supported and you want secure, low-maintenance images. Use Dockerfiles when you need full control over every layer or your stack is not covered by existing buildpacks.

## Further Resources

- [Cloud Native Buildpacks Specification](https://buildpacks.io)
- [Paketo Buildpacks Documentation](https://paketo.io/docs/)
- [Spring Boot Container Images Documentation](https://docs.spring.io/spring-boot/reference/packaging/container-images/cloud-native-buildpacks.html)
- [CNCF Buildpacks Project Page](https://www.cncf.io/projects/buildpacks/)
- [pack CLI Reference](https://buildpacks.io/docs/for-platform-operators/how-to/integrate-ci/pack/)
