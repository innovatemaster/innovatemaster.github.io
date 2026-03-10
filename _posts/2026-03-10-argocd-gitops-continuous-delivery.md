---
layout: post
title: "ArgoCD: GitOps Continuous Delivery for Kubernetes"
date: 2026-03-10 10:00 +0100
categories: [DevOps, Kubernetes]
tags: [argocd, gitops, kubernetes, continuous-delivery, ci-cd, helm, kustomize, cloud-native, cncf]
description: A practical guide to ArgoCD covering GitOps principles, installation, application management, sync strategies, multi-cluster deployments, secrets handling, CI/CD integration, and production best practices for Kubernetes-native continuous delivery.
---

# ArgoCD: GitOps Continuous Delivery for Kubernetes

Deploying applications to Kubernetes typically involves a CI pipeline that builds an image, updates manifests, and runs `kubectl apply` against the cluster. This works for small setups, but it breaks down as complexity grows. Pipelines accumulate cluster credentials, drift between desired and actual state goes undetected, and rollbacks mean re-running a pipeline rather than reverting a commit. **ArgoCD** solves these problems by flipping the model: instead of pushing changes to the cluster, ArgoCD watches a Git repository and continuously pulls the desired state into Kubernetes.

ArgoCD is a [CNCF graduated project](https://www.cncf.io/projects/argo/) and one of the most widely adopted GitOps tools in the Kubernetes ecosystem. It powers production deployments at companies of every scale, from small teams running a single cluster to enterprises managing hundreds.

## What Is GitOps?

GitOps is an operational model where the entire desired state of your infrastructure and applications is declared in a Git repository. A GitOps operator running inside the cluster continuously reconciles the actual cluster state against the declared state in Git. Any drift is detected and can be corrected automatically.

The core principles:

| Principle | What It Means |
|---|---|
| **Declarative configuration** | The entire system is described as code (YAML manifests, Helm charts, Kustomize overlays). |
| **Git as single source of truth** | The desired state lives in version-controlled Git repositories. No manual `kubectl` edits. |
| **Automated reconciliation** | An agent in the cluster continuously compares actual state to desired state and applies corrections. |
| **Pull-based delivery** | The cluster pulls changes from Git, rather than an external CI server pushing changes in. |

This matters because Git gives you audit trails, code reviews for infrastructure changes, easy rollbacks via `git revert`, and a clear history of who changed what and when.

## ArgoCD Architecture

ArgoCD runs as a set of controllers inside your Kubernetes cluster. Understanding the components helps when troubleshooting and tuning.

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  API Server   │  │  Repo Server │  │  Application     │  │
│  │  (UI + API)   │  │  (Git clone, │  │  Controller      │  │
│  │               │  │   render     │  │  (reconciliation │  │
│  │               │  │   manifests) │  │   loop)          │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
│         │                  │                   │            │
│         ▼                  ▼                   ▼            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Dex / OIDC   │  │  Redis       │  │  Kubernetes API  │  │
│  │  (SSO)        │  │  (caching)   │  │  (apply changes) │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         ▲
         │  watches
         ▼
┌──────────────────┐
│   Git Repository  │
│  (desired state)  │
└──────────────────┘
```

| Component | Role |
|---|---|
| **API Server** | Serves the web UI, gRPC/REST API, and handles authentication. This is what users and CI systems interact with. |
| **Repo Server** | Clones Git repositories and renders manifests (plain YAML, Helm, Kustomize, Jsonnet). Caches results in Redis. |
| **Application Controller** | The core reconciliation engine. Compares rendered manifests against live cluster state and detects drift. |
| **Redis** | Caches repository state and rendered manifests to reduce Git API calls and rendering overhead. |
| **Dex** | Optional SSO provider. Integrates with OIDC, LDAP, SAML, GitHub, GitLab, and other identity providers. |

## Installation

ArgoCD can be installed in several ways. The two most common are plain manifests and Helm.

### Using Plain Manifests

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

This installs the full ArgoCD stack including the web UI. For environments where only the CLI and API are needed, use the core install:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/core-install.yaml
```

### Using Helm

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace argocd --create-namespace
```

Helm gives you a `values.yaml` for fine-grained control over replicas, resource limits, ingress, and all other configuration.

### Accessing the UI

After installation, retrieve the initial admin password and port-forward the API server:

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward the API server
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open `https://localhost:8080` in your browser and log in with username `admin` and the retrieved password.

### Installing the CLI

The `argocd` CLI is the primary interface for managing applications from the terminal.

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Windows (via Chocolatey)
choco install argocd-cli
```

Log in to your ArgoCD instance:

```bash
argocd login localhost:8080
```

## Core Concepts

### Application

An **Application** is ArgoCD's central resource. It connects a source (Git repository path) to a destination (Kubernetes cluster and namespace).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: main
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Key fields:

| Field | Purpose |
|---|---|
| `source.repoURL` | Git repository containing manifests. |
| `source.targetRevision` | Branch, tag, or commit SHA to track. |
| `source.path` | Directory within the repo containing manifests. |
| `destination.server` | Target cluster API URL. Use `https://kubernetes.default.svc` for the local cluster. |
| `destination.namespace` | Target namespace for deployed resources. |
| `syncPolicy.automated` | Enables automatic sync when Git changes are detected. |
| `syncPolicy.automated.prune` | Deletes resources from the cluster that no longer exist in Git. |
| `syncPolicy.automated.selfHeal` | Reverts manual changes made directly to the cluster. |

### Project

An **AppProject** groups applications and enforces access control. It defines which repositories, clusters, and namespaces an application is allowed to use.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-backend
  namespace: argocd
spec:
  description: Backend team applications
  sourceRepos:
    - https://github.com/your-org/backend-*
  destinations:
    - server: https://kubernetes.default.svc
      namespace: backend-*
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
  roles:
    - name: deployer
      description: Can sync applications
      policies:
        - p, proj:team-backend:deployer, applications, sync, team-backend/*, allow
        - p, proj:team-backend:deployer, applications, get, team-backend/*, allow
```

The `default` project is permissive and allows any source and destination. For production environments, always create dedicated projects with scoped permissions.

### Repository

ArgoCD needs access to your Git repositories. Public repositories work out of the box. For private repositories, register credentials:

```bash
# HTTPS with token
argocd repo add https://github.com/your-org/your-repo.git \
  --username git \
  --password <personal-access-token>

# SSH
argocd repo add git@github.com:your-org/your-repo.git \
  --ssh-private-key-path ~/.ssh/id_ed25519
```

Credentials are stored as Kubernetes Secrets in the `argocd` namespace.

## Manifest Sources

ArgoCD supports multiple ways to define Kubernetes manifests. The right choice depends on your complexity and reuse requirements.

### Plain YAML

The simplest option. Place standard Kubernetes YAML files in a directory and point your Application at it.

```
k8s/
├── deployment.yaml
├── service.yaml
├── configmap.yaml
└── ingress.yaml
```

No templating, no dependencies. Works well for small applications with environment-specific repositories or branches.

### Helm

ArgoCD renders Helm charts natively without requiring Tiller or a Helm binary on the client.

```yaml
source:
  repoURL: https://charts.bitnami.com/bitnami
  chart: postgresql
  targetRevision: 16.4.1
  helm:
    releaseName: my-postgres
    valuesObject:
      auth:
        postgresPassword: changeme
      primary:
        persistence:
          size: 10Gi
```

You can also reference Helm charts stored in a Git repository:

```yaml
source:
  repoURL: https://github.com/your-org/helm-charts.git
  targetRevision: main
  path: charts/my-app
  helm:
    valueFiles:
      - values-production.yaml
```

### Kustomize

[Kustomize](https://kustomize.io) is built into `kubectl` and is a natural fit with ArgoCD. A typical structure uses a base and environment-specific overlays:

```
k8s/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── staging/
    │   ├── kustomization.yaml
    │   └── replica-patch.yaml
    └── production/
        ├── kustomization.yaml
        └── replica-patch.yaml
```

```yaml
source:
  repoURL: https://github.com/your-org/your-repo.git
  targetRevision: main
  path: k8s/overlays/production
  kustomize:
    images:
      - my-app=registry.example.com/my-app:v1.2.3
```

### Multiple Sources

ArgoCD supports combining multiple sources into a single Application. A common pattern is referencing a Helm chart from one repository and values files from another:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  sources:
    - repoURL: https://charts.bitnami.com/bitnami
      chart: postgresql
      targetRevision: 16.4.1
      helm:
        valueFiles:
          - $values/postgresql/values-production.yaml
    - repoURL: https://github.com/your-org/config-repo.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
```

The `$values` reference points to the second source entry. This separates chart definitions from environment-specific configuration.

## Sync Strategies

Syncing is the process of applying the desired state from Git to the cluster. ArgoCD offers fine-grained control over how and when this happens.

### Manual Sync

The default behavior. ArgoCD detects drift and marks the application as `OutOfSync`, but waits for a human to trigger the sync.

```bash
argocd app sync my-app
```

### Automated Sync

Enable automated sync in the Application spec to let ArgoCD apply changes as soon as it detects a new commit.

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

- **Prune** removes cluster resources that were deleted from Git.
- **Self-heal** reverts manual changes made with `kubectl edit` or `kubectl apply` directly.

Without `selfHeal`, someone could manually patch a Deployment and ArgoCD would not revert it until the next Git commit triggers a sync.

### Sync Waves and Hooks

For complex deployments, you often need resources created in a specific order: namespaces before deployments, databases before applications, migrations before services.

ArgoCD supports **sync waves** via annotations:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
```

Resources are synced in ascending wave order. Resources within the same wave are synced concurrently.

| Wave | Typical Resources |
|---|---|
| `-2` | Namespaces, CRDs |
| `-1` | ConfigMaps, Secrets, PVCs |
| `0` | Deployments, Services (default) |
| `1` | Ingress, monitoring configuration |
| `2` | Post-deploy jobs (smoke tests, notifications) |

**Sync hooks** let you run Jobs or Pods at specific lifecycle points:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: registry.example.com/my-app:v1.2.3
          command: ["./migrate", "--target", "latest"]
      restartPolicy: Never
```

Available hooks:

| Hook | When It Runs |
|---|---|
| `PreSync` | Before the main sync. Database migrations, schema changes. |
| `Sync` | During the sync, alongside normal resources. |
| `PostSync` | After all resources are synced and healthy. Notifications, smoke tests. |
| `SyncFail` | When a sync operation fails. Alerting, cleanup. |

## Handling Secrets

Kubernetes Secrets stored as plain YAML in Git are base64-encoded, not encrypted. Committing them directly is a security risk. ArgoCD supports several patterns for secure secret management.

### Sealed Secrets

[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) encrypts secrets client-side using a public key. Only the Sealed Secrets controller running in the cluster can decrypt them.

```bash
# Encrypt a secret
kubeseal --format yaml < my-secret.yaml > my-sealed-secret.yaml
```

The resulting `SealedSecret` resource is safe to commit to Git. ArgoCD applies it like any other resource, and the controller decrypts it into a standard Secret.

### External Secrets Operator

[External Secrets Operator](https://external-secrets.io) (ESO) fetches secrets from external stores such as AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, or Google Secret Manager at runtime.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: my-app-secrets
  data:
    - secretKey: db-password
      remoteRef:
        key: secret/data/my-app
        property: db-password
```

This is the most flexible approach and works well with enterprise secret management infrastructure.

### SOPS with Age or GPG

Mozilla SOPS encrypts specific values within YAML files while leaving keys readable. Combined with the [KSOPS](https://github.com/viaduct-ai/kustomize-sops) Kustomize plugin, ArgoCD can decrypt SOPS-encrypted files during manifest rendering.

```bash
# Encrypt
sops --encrypt --age <public-key> secrets.yaml > secrets.enc.yaml

# ArgoCD decrypts during rendering via KSOPS plugin
```

## App of Apps Pattern

Managing dozens of Application resources individually does not scale. The **App of Apps** pattern uses a single root Application that points to a directory of Application manifests.

```
argocd-apps/
├── app-frontend.yaml
├── app-backend.yaml
├── app-database.yaml
├── app-monitoring.yaml
└── app-ingress.yaml
```

The root Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/argocd-apps.git
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

When you add a new YAML file to the `argocd-apps/` directory and push, ArgoCD automatically creates and syncs the new Application.

### ApplicationSet

For even more dynamic scenarios, **ApplicationSet** generates Application resources from templates using generators.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-addons
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/your-org/cluster-addons.git
        revision: main
        directories:
          - path: addons/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/cluster-addons.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

This generates one Application per subdirectory under `addons/`. Common generators include:

| Generator | Use Case |
|---|---|
| **Git directory** | One app per directory in a repo. |
| **Git file** | One app per config file (JSON/YAML) in a repo. |
| **Cluster** | One app per registered cluster. Deploy addons across all clusters. |
| **List** | Explicitly defined list of parameter sets. |
| **Matrix** | Cartesian product of two generators (e.g., clusters × apps). |
| **Merge** | Combine and override parameters from multiple generators. |

## Multi-Cluster Deployments

ArgoCD can manage applications across multiple Kubernetes clusters from a single control plane.

### Registering Clusters

```bash
# Add a cluster using kubeconfig context
argocd cluster add my-staging-context

# Verify
argocd cluster list
```

ArgoCD creates a ServiceAccount in the target cluster and stores the credentials as a Secret in the `argocd` namespace.

### Deploying Across Clusters

With ApplicationSet and the cluster generator, you can deploy the same application to every registered cluster:

```yaml
generators:
  - clusters:
      selector:
        matchLabels:
          env: production
template:
  spec:
    destination:
      server: '{{server}}'
      namespace: my-app
```

This deploys `my-app` to every cluster labeled `env: production`. When you register a new production cluster, the application is automatically deployed.

## CI/CD Integration

ArgoCD handles the CD side. Your existing CI pipeline still builds images, runs tests, and pushes artifacts. The handoff happens when CI updates the image tag in Git.

### Typical Workflow

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Developer│────▶│  CI       │────▶│  Git     │────▶│  ArgoCD  │
│  pushes   │     │  builds   │     │  repo    │     │  syncs   │
│  code     │     │  image    │     │  updated │     │  cluster │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
```

1. Developer pushes code to the application repository.
2. CI builds and tests the application, then pushes a container image with a unique tag.
3. CI updates the image tag in the deployment repository (or the same repo in a different path) and commits.
4. ArgoCD detects the Git change and syncs the new manifests to the cluster.

### Updating Image Tags from CI

In a GitHub Actions workflow:

```yaml
- name: Update image tag
  run: |
    cd deploy-repo
    kustomize edit set image my-app=registry.example.com/my-app:${{ github.sha }}
    git add .
    git commit -m "chore: update my-app to ${{ github.sha }}"
    git push
```

Alternatively, use [ArgoCD Image Updater](https://argocd-image-updater.readthedocs.io/) to automate image tag updates by watching a container registry:

```yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: my-app=registry.example.com/my-app
    argocd-image-updater.argoproj.io/my-app.update-strategy: semver
    argocd-image-updater.argoproj.io/my-app.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
```

## Monitoring and Notifications

### Health Checks

ArgoCD has built-in health assessments for standard Kubernetes resources. A Deployment is healthy when all replicas are available. A Service is healthy when it has endpoints. Custom health checks can be added for CRDs via Lua scripts in the ArgoCD ConfigMap.

Application health statuses:

| Status | Meaning |
|---|---|
| **Healthy** | All resources report healthy status. |
| **Progressing** | Resources are being updated (e.g., rollout in progress). |
| **Degraded** | One or more resources report errors or failures. |
| **Suspended** | Application sync is paused (e.g., paused rollout). |
| **Missing** | Resources declared in Git do not exist in the cluster. |

### Notifications

[ArgoCD Notifications](https://argocd-notifications.readthedocs.io/) (bundled since ArgoCD 2.6) sends alerts when application state changes. Supported channels include Slack, Microsoft Teams, email, webhooks, GitHub, and Grafana.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-sync-succeeded]
  template.app-sync-succeeded: |
    message: |
      Application {{.app.metadata.name}} has been synced successfully.
      Revision: {{.app.status.sync.revision}}
  service.slack: |
    token: $slack-token
    channel: deployments
```

## Disaster Recovery

ArgoCD itself follows the GitOps model -- your desired cluster state is in Git, so recovering from a cluster loss is straightforward:

1. Provision a new cluster.
2. Install ArgoCD.
3. Point it at the same Git repositories.
4. ArgoCD recreates everything.

For ArgoCD's own configuration (projects, repositories, credentials), export and back up regularly:

```bash
argocd admin export > argocd-backup.yaml
```

Restore with:

```bash
argocd admin import - < argocd-backup.yaml
```

## Production Best Practices

| Practice | Why |
|---|---|
| **Separate app and config repos** | Decouples application source code from deployment configuration. CI commits image tags to the config repo, ArgoCD watches the config repo. |
| **Pin to specific revisions** | Use tags or commit SHAs for production instead of branch heads. `main` is fine for staging. |
| **Enable self-heal** | Prevents manual cluster edits from creating hidden drift. |
| **Use AppProjects** | Restrict which repos and namespaces each team can deploy to. Principle of least privilege. |
| **Set resource limits on ArgoCD** | The Repo Server and Application Controller can consume significant memory in large installations. Size them based on the number of applications and manifest complexity. |
| **Configure SSO** | Replace the default admin account with OIDC/SAML integration. Disable the admin account after setup. |
| **Use webhook triggers** | Configure GitHub/GitLab webhooks to notify ArgoCD of new commits. Reduces sync detection latency from the default 3-minute polling interval. |
| **Diff customization** | Use `ignoreDifferences` to suppress noise from fields that Kubernetes controllers mutate (e.g., `status`, `metadata.generation`). |
| **Enable resource tracking** | Use `argocd.argoproj.io/tracking-id` annotation-based tracking for better multi-tool compatibility. |

## ArgoCD vs Other GitOps Tools

| Feature | ArgoCD | Flux | Jenkins X |
|---|---|---|---|
| **CNCF status** | Graduated | Graduated | Sandbox (archived) |
| **UI** | Full web dashboard | No built-in UI (Weave GitOps available) | Web UI |
| **Multi-cluster** | Native support | Via Flux multi-tenancy | Limited |
| **Helm support** | Native rendering | Helm controller | Helm-based |
| **Kustomize** | Native | Native | Via plugins |
| **RBAC** | Fine-grained via AppProjects | Kubernetes-native RBAC | Kubernetes-native RBAC |
| **Notifications** | Built-in | Via Flux notification controller | Via plugins |
| **Learning curve** | Moderate | Moderate | Steep |
| **Best for** | Teams wanting a UI, multi-cluster management, and fine-grained RBAC | Teams preferring a lightweight, controller-based approach | Full CI/CD platform (consider alternatives since archival) |

ArgoCD and Flux are both excellent choices. ArgoCD stands out with its web UI, multi-cluster management, and the ApplicationSet controller. Flux takes a more Kubernetes-native approach where everything is a CRD and there is no central server.

## Getting Started Checklist

If you are adopting ArgoCD for the first time, this sequence will get you to a solid foundation:

1. **Install ArgoCD** in a dedicated namespace on your cluster.
2. **Set up SSO** with your identity provider. Disable the default admin account.
3. **Create AppProjects** for each team or environment with scoped permissions.
4. **Start with manual sync** until the team is comfortable with the workflow.
5. **Structure your config repo** with Kustomize overlays per environment.
6. **Add one application** end to end: CI builds image, updates config repo, ArgoCD syncs.
7. **Enable automated sync** with prune and self-heal for staging first, then production.
8. **Set up notifications** to your team's Slack or Teams channel.
9. **Configure webhooks** from your Git provider to reduce sync latency.
10. **Monitor ArgoCD itself** -- expose Prometheus metrics and set up alerts for sync failures and degraded health.

ArgoCD turns Kubernetes deployment from an imperative, error-prone process into a declarative, auditable workflow. The learning curve is real, but once the GitOps model is in place, deployments become boring in the best possible way: a reviewed commit, an automatic sync, and a verified healthy state.
