---
layout: post
title: "Tekton: Kubernetes-Native CI/CD Pipelines"
date: 2026-03-10 10:00 +0100
categories: [DevOps, CI/CD]
tags: [tekton, kubernetes, cicd, pipelines, cloud-native, devops, containers, gitops, continuous-delivery, java]
description: A practical guide to Tekton, the Kubernetes-native CI/CD framework. Covers architecture, core concepts, building pipelines, triggers, catalog tasks, Java/Maven builds, comparison with Jenkins and GitHub Actions, and production best practices.
---

# Tekton: Kubernetes-Native CI/CD Pipelines

Most CI/CD systems were designed before Kubernetes existed. Jenkins, GitLab CI, and GitHub Actions all bolt container execution onto platforms that were originally built around VMs, shell scripts, or proprietary runtimes. They work, but they carry assumptions that do not always map cleanly onto a cloud-native world where everything runs in pods, configuration is declarative YAML, and infrastructure is managed through Kubernetes APIs.

**Tekton** takes a different approach. It is a CI/CD framework that runs _inside_ Kubernetes as a set of Custom Resource Definitions (CRDs). Pipelines, tasks, and runs are all first-class Kubernetes objects. There is no separate CI server to maintain, no plugin compatibility matrix to worry about, and no impedance mismatch between where your applications run and where they are built.

This guide walks through Tekton's architecture, core building blocks, practical pipeline construction, trigger setup, and production patterns, with a focus on Java and Spring Boot workflows.

## Why Tekton?

Before diving into the details, it helps to understand the problems Tekton was designed to solve.

| Problem | Traditional CI/CD | Tekton |
|---|---|---|
| **Infrastructure** | Dedicated CI server (Jenkins controller, GitLab runners) that must be provisioned, patched, and scaled independently. | Runs as CRDs inside your existing Kubernetes cluster. No separate infrastructure. |
| **Scaling** | Runner pools with fixed capacity or auto-scaling that lags behind demand. | Each pipeline run creates pods on demand. Kubernetes handles scheduling and resource allocation. |
| **Isolation** | Shared runners risk dependency conflicts and security cross-contamination between projects. | Every task step runs in its own container within a pod. Full isolation by default. |
| **Portability** | Pipelines are tied to a specific vendor (Jenkinsfile, `.gitlab-ci.yml`, `.github/workflows`). | Tekton pipelines are standard Kubernetes resources. They run on any cluster with Tekton installed. |
| **Declarative config** | Mix of imperative scripts and declarative config. Jenkins pipelines are Groovy code. | Everything is declarative YAML managed through `kubectl` or GitOps tools. |
| **Extensibility** | Plugin systems with varying quality and compatibility. | Reusable Tasks from the Tekton Catalog (Tekton Hub), composed freely in pipelines. |

Tekton is not a hosted CI/CD product. It is an open-source framework (part of the [CD Foundation](https://cd.foundation/)) that gives you the building blocks to construct CI/CD systems that are native to your Kubernetes environment.

## Architecture Overview

Tekton consists of several components that are installed into your cluster as Kubernetes operators.

### Core Components

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                     │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │   Tekton      │  │   Tekton      │  │   Tekton       │  │
│  │   Pipelines   │  │   Triggers    │  │   Dashboard    │  │
│  │   Controller  │  │   Controller  │  │   (optional)   │  │
│  └──────┬───────┘  └──────┬───────┘  └───────────────┘  │
│         │                  │                              │
│         ▼                  ▼                              │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            Kubernetes API Server (CRDs)              │ │
│  │  Task | Pipeline | TaskRun | PipelineRun | Trigger  │ │
│  └─────────────────────────────────────────────────────┘ │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   Pod (Task)  │  │   Pod (Task)  │  │   Pod (Task)  │   │
│  │  ┌─────────┐  │  │  ┌─────────┐  │  │  ┌─────────┐  │   │
│  │  │ Step 1  │  │  │  │ Step 1  │  │  │  │ Step 1  │  │   │
│  │  ├─────────┤  │  │  ├─────────┤  │  │  ├─────────┤  │   │
│  │  │ Step 2  │  │  │  │ Step 2  │  │  │  │ Step 2  │  │   │
│  │  └─────────┘  │  │  └─────────┘  │  │  └─────────┘  │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
```

- **Tekton Pipelines** is the core component. It watches for Task, Pipeline, TaskRun, and PipelineRun resources and creates pods to execute them.
- **Tekton Triggers** listens for external events (webhooks, messages) and creates PipelineRuns in response.
- **Tekton Dashboard** provides a web UI for monitoring runs and viewing logs.
- **Tekton CLI (`tkn`)** is a command-line tool for interacting with Tekton resources.

### How Execution Works

When you create a `PipelineRun`, the Tekton controller:

1. Resolves the referenced `Pipeline` and its `Tasks`.
2. Determines the execution order based on `runAfter` dependencies and resource constraints.
3. Creates a Kubernetes Pod for each Task, with one init container per Step.
4. Steps within a Task execute sequentially inside the same Pod, sharing a filesystem.
5. Tasks within a Pipeline can run in parallel unless explicit ordering is defined.
6. Results and artifacts are passed between Tasks through workspace volumes or result parameters.

## Installation

Tekton installs into any Kubernetes cluster with a single `kubectl apply`.

### Prerequisites

- A Kubernetes cluster (1.27+) with `kubectl` configured.
- Cluster-admin permissions (Tekton installs CRDs and controllers).

### Install Tekton Pipelines

```bash
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
```

Verify the installation:

```bash
kubectl get pods -n tekton-pipelines
```

You should see `tekton-pipelines-controller` and `tekton-pipelines-webhook` running.

### Install Tekton Triggers (optional)

```bash
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
```

### Install Tekton CLI

```bash
# macOS
brew install tektoncd-cli

# Linux (Debian/Ubuntu)
sudo apt-get install tektoncd-cli

# Windows (via Chocolatey)
choco install tektoncd-cli
```

### Install Tekton Dashboard (optional)

```bash
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
```

Access it via port-forward:

```bash
kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097
```

## Core Concepts

Tekton's resource model has a small number of primitives that compose together. Understanding these is the key to building effective pipelines.

### Step

A **Step** is a single container invocation. It runs a command inside a container image. Steps are the smallest unit of execution.

```yaml
steps:
  - name: build
    image: maven:3.9-eclipse-temurin-21
    command: ["mvn"]
    args: ["clean", "package", "-DskipTests"]
```

### Task

A **Task** is an ordered sequence of Steps that execute in the same Pod. Steps share a filesystem, so artifacts produced by one Step are available to the next.

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: maven-build
spec:
  params:
    - name: goals
      type: array
      default: ["clean", "package"]
  workspaces:
    - name: source
      description: The workspace containing the Maven project
  steps:
    - name: maven
      image: maven:3.9-eclipse-temurin-21
      workingDir: $(workspaces.source.path)
      command: ["mvn"]
      args: ["$(params.goals[*])"]
```

Key characteristics of Tasks:
- Tasks are **reusable**. Define once, reference in many Pipelines.
- Tasks declare **parameters** for configuration and **workspaces** for shared storage.
- Tasks declare **results** that can be consumed by subsequent Tasks in a Pipeline.

### Pipeline

A **Pipeline** is a directed acyclic graph (DAG) of Tasks. It defines the order of execution, parameter passing, and workspace sharing.

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: build-and-deploy
spec:
  params:
    - name: repo-url
      type: string
    - name: image-name
      type: string
  workspaces:
    - name: shared-workspace
    - name: docker-credentials
  tasks:
    - name: fetch-source
      taskRef:
        name: git-clone
      workspaces:
        - name: output
          workspace: shared-workspace
      params:
        - name: url
          value: $(params.repo-url)

    - name: build
      taskRef:
        name: maven-build
      runAfter:
        - fetch-source
      workspaces:
        - name: source
          workspace: shared-workspace

    - name: build-image
      taskRef:
        name: kaniko
      runAfter:
        - build
      workspaces:
        - name: source
          workspace: shared-workspace
        - name: dockerconfig
          workspace: docker-credentials
      params:
        - name: IMAGE
          value: $(params.image-name)
```

Tasks without `runAfter` dependencies run in parallel. In the example above, `build` waits for `fetch-source`, and `build-image` waits for `build`.

### TaskRun and PipelineRun

These are the execution instances. A `TaskRun` executes a single Task; a `PipelineRun` executes a full Pipeline.

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: build-and-deploy-run-
spec:
  pipelineRef:
    name: build-and-deploy
  params:
    - name: repo-url
      value: "https://github.com/myorg/myapp.git"
    - name: image-name
      value: "registry.example.com/myapp:latest"
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
    - name: docker-credentials
      secret:
        secretName: docker-registry-credentials
```

Create the run:

```bash
kubectl create -f pipelinerun.yaml
```

Monitor progress with the Tekton CLI:

```bash
tkn pipelinerun logs build-and-deploy-run-abc12 -f
```

### Workspaces

**Workspaces** are the mechanism for sharing data between Steps within a Task and between Tasks in a Pipeline. They map to Kubernetes volumes.

| Workspace Type | Backed By | Use Case |
|---|---|---|
| `volumeClaimTemplate` | Dynamically provisioned PVC | Source code, build artifacts |
| `persistentVolumeClaim` | Existing PVC | Maven/Gradle caches |
| `secret` | Kubernetes Secret | Docker credentials, SSH keys |
| `configMap` | Kubernetes ConfigMap | Build configuration files |
| `emptyDir` | Ephemeral volume | Temporary scratch space |

### Results

Tasks can emit **results**, which are small string values (max 4096 bytes) that can be referenced by subsequent Tasks.

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: read-version
spec:
  workspaces:
    - name: source
  results:
    - name: version
      description: The project version from pom.xml
  steps:
    - name: extract-version
      image: maven:3.9-eclipse-temurin-21
      workingDir: $(workspaces.source.path)
      script: |
        VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
        echo -n "$VERSION" | tee $(results.version.path)
```

Reference the result in a downstream Task:

```yaml
tasks:
  - name: tag-image
    params:
      - name: tag
        value: $(tasks.read-version.results.version)
```

## Practical Example: Java/Spring Boot Pipeline

Let us build a complete pipeline for a Spring Boot application that clones the repository, runs tests, builds a container image, and deploys to Kubernetes.

### Step 1: Define the Test Task

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: maven-test
spec:
  workspaces:
    - name: source
    - name: maven-cache
      optional: true
  steps:
    - name: test
      image: maven:3.9-eclipse-temurin-21
      workingDir: $(workspaces.source.path)
      command: ["mvn"]
      args:
        - "test"
        - "-Dmaven.repo.local=$(workspaces.maven-cache.path)/.m2/repository"
      resources:
        requests:
          memory: "512Mi"
          cpu: "500m"
        limits:
          memory: "2Gi"
          cpu: "2"
```

### Step 2: Define the Build Task

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: maven-package
spec:
  params:
    - name: build-args
      type: array
      default: ["-DskipTests"]
  workspaces:
    - name: source
    - name: maven-cache
      optional: true
  results:
    - name: artifact-name
      description: Name of the built JAR file
  steps:
    - name: package
      image: maven:3.9-eclipse-temurin-21
      workingDir: $(workspaces.source.path)
      command: ["mvn"]
      args:
        - "package"
        - "-Dmaven.repo.local=$(workspaces.maven-cache.path)/.m2/repository"
        - "$(params.build-args[*])"

    - name: find-artifact
      image: alpine:3.20
      workingDir: $(workspaces.source.path)
      script: |
        JAR=$(find target -name "*.jar" -not -name "*-sources.jar" | head -1)
        echo -n "$(basename $JAR)" | tee $(results.artifact-name.path)
```

### Step 3: Build the Container Image with Kaniko

Tekton runs inside containers, so you cannot use Docker-in-Docker. **Kaniko** builds container images without requiring a Docker daemon.

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: build-push-image
spec:
  params:
    - name: image
      type: string
    - name: dockerfile
      type: string
      default: "./Dockerfile"
  workspaces:
    - name: source
    - name: dockerconfig
  steps:
    - name: build-and-push
      image: gcr.io/kaniko-project/executor:latest
      args:
        - "--dockerfile=$(params.dockerfile)"
        - "--context=$(workspaces.source.path)"
        - "--destination=$(params.image)"
        - "--cache=true"
      env:
        - name: DOCKER_CONFIG
          value: $(workspaces.dockerconfig.path)
```

### Step 4: Deploy to Kubernetes

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: kubernetes-deploy
spec:
  params:
    - name: image
      type: string
    - name: deployment-name
      type: string
    - name: namespace
      type: string
      default: "default"
  steps:
    - name: deploy
      image: bitnami/kubectl:latest
      script: |
        kubectl set image deployment/$(params.deployment-name) \
          $(params.deployment-name)=$(params.image) \
          -n $(params.namespace)
        kubectl rollout status deployment/$(params.deployment-name) \
          -n $(params.namespace) --timeout=300s
```

### Step 5: Assemble the Pipeline

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: spring-boot-pipeline
spec:
  params:
    - name: repo-url
      type: string
    - name: repo-revision
      type: string
      default: "main"
    - name: image
      type: string
    - name: deployment-name
      type: string

  workspaces:
    - name: shared-workspace
    - name: maven-cache
    - name: docker-credentials

  tasks:
    - name: clone
      taskRef:
        name: git-clone
      workspaces:
        - name: output
          workspace: shared-workspace
      params:
        - name: url
          value: $(params.repo-url)
        - name: revision
          value: $(params.repo-revision)

    - name: test
      taskRef:
        name: maven-test
      runAfter: ["clone"]
      workspaces:
        - name: source
          workspace: shared-workspace
        - name: maven-cache
          workspace: maven-cache

    - name: build
      taskRef:
        name: maven-package
      runAfter: ["test"]
      workspaces:
        - name: source
          workspace: shared-workspace
        - name: maven-cache
          workspace: maven-cache

    - name: build-image
      taskRef:
        name: build-push-image
      runAfter: ["build"]
      workspaces:
        - name: source
          workspace: shared-workspace
        - name: dockerconfig
          workspace: docker-credentials
      params:
        - name: image
          value: $(params.image)

    - name: deploy
      taskRef:
        name: kubernetes-deploy
      runAfter: ["build-image"]
      params:
        - name: image
          value: $(params.image)
        - name: deployment-name
          value: $(params.deployment-name)

  finally:
    - name: notify
      taskRef:
        name: send-notification
      params:
        - name: status
          value: $(tasks.deploy.status)
```

The `finally` block runs regardless of whether previous tasks succeeded or failed, similar to a `try/finally` block. It is ideal for notifications, cleanup, or reporting.

### Step 6: Run the Pipeline

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: spring-boot-run-
spec:
  pipelineRef:
    name: spring-boot-pipeline
  params:
    - name: repo-url
      value: "https://github.com/myorg/spring-boot-app.git"
    - name: image
      value: "registry.example.com/spring-boot-app:v1.2.0"
    - name: deployment-name
      value: "spring-boot-app"
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi
    - name: maven-cache
      persistentVolumeClaim:
        claimName: maven-cache-pvc
    - name: docker-credentials
      secret:
        secretName: registry-credentials
```

```bash
kubectl create -f pipelinerun.yaml
tkn pipelinerun logs -f --last
```

## Tekton Triggers

Triggers let you automate pipeline execution in response to external events like Git pushes, pull requests, or webhook calls.

### Components

- **EventListener** exposes an HTTP endpoint that receives incoming events.
- **Trigger** binds an event to a pipeline, extracting parameters from the event payload.
- **TriggerBinding** maps fields from the event payload to parameters.
- **TriggerTemplate** defines the PipelineRun (or TaskRun) to create.
- **Interceptors** filter and transform events before they reach the Trigger (e.g., GitHub webhook validation, CEL filtering).

### GitHub Push Trigger Example

**TriggerBinding** -- extracts data from the GitHub push webhook payload:

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: github-push-binding
spec:
  params:
    - name: repo-url
      value: $(body.repository.clone_url)
    - name: revision
      value: $(body.after)
    - name: branch
      value: $(extensions.branch_name)
```

**TriggerTemplate** -- creates a PipelineRun with the extracted parameters:

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: spring-boot-trigger-template
spec:
  params:
    - name: repo-url
    - name: revision
    - name: branch
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: triggered-spring-boot-
      spec:
        pipelineRef:
          name: spring-boot-pipeline
        params:
          - name: repo-url
            value: $(tt.params.repo-url)
          - name: repo-revision
            value: $(tt.params.revision)
          - name: image
            value: "registry.example.com/spring-boot-app:$(tt.params.revision)"
          - name: deployment-name
            value: "spring-boot-app"
        workspaces:
          - name: shared-workspace
            volumeClaimTemplate:
              spec:
                accessModes: ["ReadWriteOnce"]
                resources:
                  requests:
                    storage: 2Gi
          - name: maven-cache
            persistentVolumeClaim:
              claimName: maven-cache-pvc
          - name: docker-credentials
            secret:
              secretName: registry-credentials
```

**EventListener** -- ties everything together and exposes the webhook endpoint:

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: github-listener
spec:
  serviceAccountName: tekton-triggers-sa
  triggers:
    - name: push-trigger
      interceptors:
        - ref:
            name: "github"
          params:
            - name: "secretRef"
              value:
                secretName: github-webhook-secret
                secretKey: secret
            - name: "eventTypes"
              value: ["push"]
        - ref:
            name: "cel"
          params:
            - name: "filter"
              value: "body.ref.startsWith('refs/heads/main')"
      bindings:
        - ref: github-push-binding
      template:
        ref: spring-boot-trigger-template
```

The CEL interceptor filters events so only pushes to the `main` branch trigger a pipeline run. The GitHub interceptor validates the webhook signature.

Expose the EventListener to the internet (via Ingress, LoadBalancer, or a tool like smee.io for development) and configure your GitHub repository's webhook settings to point at it.

## Tekton Catalog and Hub

The [Tekton Hub](https://hub.tekton.dev/) hosts a catalog of reusable Tasks and Pipelines contributed by the community. Instead of writing everything from scratch, you can install catalog tasks directly.

### Commonly Used Catalog Tasks

| Task | Purpose |
|---|---|
| `git-clone` | Clone a Git repository into a workspace |
| `maven` | Run Maven goals |
| `gradle` | Run Gradle tasks |
| `kaniko` | Build and push container images without Docker |
| `buildah` | Build OCI images using Buildah |
| `helm-upgrade-from-source` | Deploy Helm charts |
| `kubernetes-actions` | Run kubectl commands |
| `send-to-webhook-slack` | Send Slack notifications |
| `sonarqube-scanner` | Run SonarQube analysis |
| `openshift-client` | Run OpenShift CLI commands |

### Installing Catalog Tasks

Using the Tekton CLI:

```bash
tkn hub install task git-clone
tkn hub install task maven
tkn hub install task kaniko
```

Or directly with `kubectl`:

```bash
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml
```

Catalog tasks follow the same interface conventions (params, workspaces, results), making them interchangeable and composable.

## Tekton vs Jenkins vs GitHub Actions

Choosing between CI/CD tools depends on your infrastructure, team skills, and requirements. Here is a practical comparison.

| Aspect | Tekton | Jenkins | GitHub Actions |
|---|---|---|---|
| **Runtime** | Kubernetes pods | Jenkins agents (VMs, containers, bare metal) | GitHub-hosted or self-hosted runners |
| **Configuration** | Kubernetes YAML (CRDs) | Jenkinsfile (Groovy DSL) | YAML workflow files |
| **Hosting** | Self-hosted on any K8s cluster | Self-hosted | GitHub-hosted (free tier) or self-hosted |
| **Scaling** | Kubernetes-native autoscaling | Requires manual or plugin-based scaling | Automatic (hosted) or manual (self-hosted) |
| **Vendor lock-in** | None (Kubernetes standard) | Low (open source, portable) | High (tied to GitHub) |
| **Learning curve** | Steep (requires Kubernetes knowledge) | Moderate (large community, many tutorials) | Low (great docs, huge marketplace) |
| **UI** | Tekton Dashboard (basic) | Jenkins UI (dated but functional) | GitHub web UI (polished) |
| **Marketplace** | Tekton Hub (~200 tasks) | Jenkins plugins (~1800) | GitHub Marketplace (~20,000 actions) |
| **Secret management** | Kubernetes Secrets, external-secrets-operator | Jenkins credentials store, plugins | GitHub Secrets, OIDC |
| **Best for** | Teams already on Kubernetes who want platform-native CI/CD | Complex enterprise pipelines with deep integration needs | Teams using GitHub who want fast setup |

### When to Choose Tekton

- Your applications already run on Kubernetes and you want CI/CD to live in the same plane.
- You need a vendor-neutral CI/CD framework that avoids platform lock-in.
- You are building an internal developer platform and want CI/CD as composable Kubernetes primitives.
- Compliance requires that build workloads run inside your own infrastructure.
- You want to standardize CI/CD across multiple teams with reusable Tasks.

### When to Look Elsewhere

- You do not run Kubernetes. Tekton has no standalone mode.
- Your team lacks Kubernetes expertise. The learning curve is real.
- You want a turnkey SaaS solution with minimal maintenance.
- You need a rich web-based pipeline editor or visual workflow builder.

## Production Best Practices

### Resource Management

Set resource requests and limits on Steps to prevent noisy-neighbor problems.

```yaml
steps:
  - name: build
    image: maven:3.9-eclipse-temurin-21
    resources:
      requests:
        memory: "1Gi"
        cpu: "1"
      limits:
        memory: "4Gi"
        cpu: "4"
```

### Caching Dependencies

Maven and Gradle downloads can dominate build times. Use a PersistentVolumeClaim for the local repository cache.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: maven-cache-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
```

Reference it as a workspace in your PipelineRun. With `ReadWriteMany`, multiple concurrent pipelines can share the same cache.

### Timeouts

Prevent hung builds from consuming cluster resources indefinitely.

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: build-run-
spec:
  pipelineRef:
    name: spring-boot-pipeline
  timeouts:
    pipeline: "1h"
    tasks: "30m"
    finally: "10m"
```

### Pruning Old Runs

PipelineRuns and TaskRuns accumulate as Kubernetes resources. Use the Tekton results API or a CronJob to clean up old runs.

```bash
# Delete PipelineRuns older than 7 days
tkn pipelinerun delete --keep 50

# Or use kubectl with a label selector
kubectl delete pipelinerun -l tekton.dev/pipeline=spring-boot-pipeline \
  --field-selector "status.completionTime<$(date -d '7 days ago' -Iseconds)"
```

For automated cleanup, Tekton supports a `keep` count on the PipelineRun pruner, or you can configure a Kubernetes CronJob.

### Security

- **Use least-privilege ServiceAccounts.** Create a dedicated ServiceAccount for each pipeline with only the RBAC permissions it needs.
- **Avoid mounting the default ServiceAccount token.** Set `automountServiceAccountToken: false` where possible.
- **Sign and verify images.** Integrate Cosign or Sigstore into your image-build tasks to sign OCI images and verify them at deployment.
- **Use Tekton Chains.** Tekton Chains automatically signs TaskRun and PipelineRun results, providing supply-chain security with in-toto attestations.
- **Scan images.** Add a Trivy or Grype step to scan built images for vulnerabilities before pushing to production.

```yaml
steps:
  - name: scan
    image: aquasec/trivy:latest
    command: ["trivy"]
    args:
      - "image"
      - "--exit-code"
      - "1"
      - "--severity"
      - "HIGH,CRITICAL"
      - "$(params.image)"
```

### Observability

- **Logs.** Use `tkn pipelinerun logs` or the Tekton Dashboard. For long-term log retention, ship logs to your centralized logging stack (Loki, Elasticsearch).
- **Metrics.** Tekton Pipelines exposes Prometheus metrics on port 9090. Track pipeline duration, success rates, and queue times.
- **Traces.** Tekton supports OpenTelemetry tracing. Enable it by configuring the `feature-flags` ConfigMap.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
  namespace: tekton-pipelines
data:
  enable-api-fields: "beta"
  results-from: "sidecar-logs"
```

## Integrating with GitOps

Tekton pairs well with GitOps tools like Argo CD or Flux. A common pattern:

1. Tekton builds and pushes the container image.
2. Tekton updates the image tag in a GitOps repository (e.g., Kustomize overlay or Helm values file).
3. Argo CD detects the commit and syncs the deployment.

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: update-gitops-repo
spec:
  params:
    - name: image-tag
      type: string
    - name: gitops-repo-url
      type: string
    - name: deployment-file
      type: string
      default: "k8s/deployment.yaml"
  workspaces:
    - name: ssh-credentials
  steps:
    - name: update-and-push
      image: alpine/git:latest
      script: |
        git clone $(params.gitops-repo-url) /tmp/gitops
        cd /tmp/gitops
        sed -i "s|image:.*|image: $(params.image-tag)|g" $(params.deployment-file)
        git add .
        git commit -m "Update image to $(params.image-tag)"
        git push origin main
```

This keeps a clean separation between the CI pipeline (build and test) and the CD process (deploy), with Git as the single source of truth.

## Quick Reference: Tekton CLI Commands

| Command | Description |
|---|---|
| `tkn task list` | List all Tasks |
| `tkn pipeline list` | List all Pipelines |
| `tkn pipelinerun list` | List all PipelineRuns |
| `tkn pipelinerun logs -f --last` | Follow logs of the most recent run |
| `tkn pipelinerun describe <name>` | Show details of a PipelineRun |
| `tkn pipelinerun cancel <name>` | Cancel a running PipelineRun |
| `tkn pipelinerun delete --keep 10` | Delete all but the 10 most recent runs |
| `tkn hub search maven` | Search the Tekton Hub for Tasks |
| `tkn hub install task git-clone` | Install a catalog Task |
| `tkn task start maven-build --showlog` | Start a TaskRun and follow its logs |

## Summary

Tekton gives you CI/CD that speaks the same language as the rest of your Kubernetes infrastructure. Pipelines are Kubernetes resources, execution happens in pods, and the entire system is managed through `kubectl` and standard Kubernetes tooling. There is no separate server to maintain, no proprietary runtime, and no vendor lock-in.

The trade-off is complexity. You need Kubernetes knowledge, the YAML is verbose compared to GitHub Actions, and the ecosystem is smaller than Jenkins or GitHub Marketplace. But if your team already operates on Kubernetes, Tekton eliminates the gap between where your applications run and where they are built. Everything lives in the same cluster, governed by the same RBAC, monitored by the same tools, and managed through the same GitOps workflows.

Start with the catalog tasks from Tekton Hub, build a pipeline for one project, and expand from there. The composable Task model means your investment in reusable build steps pays dividends across every project in your organization.

## Further Reading

- [Tekton Documentation](https://tekton.dev/docs/)
- [Tekton Hub -- Reusable Tasks and Pipelines](https://hub.tekton.dev/)
- [Tekton GitHub Repository](https://github.com/tektoncd/pipeline)
- [CD Foundation](https://cd.foundation/)
- [Tekton Chains -- Supply Chain Security](https://tekton.dev/docs/chains/)
- [Kaniko -- Building Container Images in Kubernetes](https://github.com/GoogleContainerTools/kaniko)
