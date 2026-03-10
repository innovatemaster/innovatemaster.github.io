---
layout: post
title: "Red Hat OpenShift and Its Free Alternatives: A Practical Comparison"
date: 2026-03-10 10:00 +0100
categories: [DevOps, Containers]
tags: [openshift, kubernetes, okd, k3s, containers, docker, devops, cloud-native, microshift, rancher, self-hosted]
description: A practical comparison of Red Hat OpenShift and its best free alternatives including OKD, K3s, MicroShift, Rancher, and vanilla Kubernetes, helping you choose the right container platform for your workload.
---

# Red Hat OpenShift and Its Free Alternatives: A Practical Comparison

Running containerized applications at scale requires more than just Docker and a prayer. You need orchestration, networking, security policies, image registries, CI/CD pipelines, and a way to manage it all without losing your mind. Red Hat OpenShift has been one of the most popular enterprise Kubernetes platforms for years, bundling all of this into a single, opinionated product. But it comes with a price tag that puts it out of reach for many teams, especially startups, small businesses, and individual developers.

This guide walks through what OpenShift offers, where it falls short, and covers the best free alternatives available today so you can run production-grade container workloads without an enterprise license.

## Red Hat OpenShift

[Red Hat OpenShift](https://www.redhat.com/en/technologies/cloud-computing/openshift) is an enterprise Kubernetes platform that wraps upstream Kubernetes with developer tooling, security defaults, an integrated container registry, CI/CD pipelines, and a polished web console. It is built on top of Kubernetes but adds significant value (and opinions) on top of the core orchestrator.

### What It Does Well

- **Enterprise-grade security.** OpenShift enforces Security Context Constraints (SCCs) by default, runs containers as non-root, and ships with a built-in OAuth server. Security is not an afterthought; it is baked into every layer.
- **Developer experience.** Source-to-Image (S2I) builds let developers push code and have OpenShift build and deploy container images automatically without writing Dockerfiles. The built-in web console provides a project-centric view that abstracts away much of Kubernetes' complexity.
- **Integrated CI/CD.** OpenShift Pipelines (based on Tekton) and OpenShift GitOps (based on Argo CD) are first-class citizens, not add-ons bolted on after the fact.
- **OperatorHub.** A curated marketplace of Kubernetes Operators for databases, message brokers, monitoring stacks, and more. One-click installation of complex stateful workloads.
- **Multi-cluster management.** Red Hat Advanced Cluster Management (ACM) provides a single pane of glass for managing multiple OpenShift clusters across hybrid and multi-cloud environments.
- **Certified ecosystem.** Red Hat certifies operators, container images, and Helm charts, giving enterprises confidence that components are tested together and supported.
- **Long-term support.** Each OpenShift release receives 18+ months of full support with backported security fixes, which matters for regulated industries.

### Where It Falls Short

| Limitation | Details |
|------------|---------|
| **Cost** | OpenShift subscriptions are expensive. Pricing varies by deployment model, but expect thousands of dollars per node per year. There is no free production tier. |
| **Complexity** | Installing and maintaining OpenShift requires significant expertise. The installer is opinionated about infrastructure, DNS, and load balancing. |
| **Resource overhead** | The platform itself consumes substantial CPU and memory. A minimal OpenShift cluster needs far more resources than a vanilla Kubernetes cluster. |
| **Opinionated defaults** | Security Context Constraints and restricted pod security can break third-party Helm charts that assume root access or privileged containers. |
| **Vendor lock-in** | While built on Kubernetes, OpenShift-specific features (S2I builds, DeploymentConfigs, Routes) do not exist outside the OpenShift ecosystem. |
| **Update cadence** | OpenShift lags behind upstream Kubernetes by several months. If you need the latest Kubernetes features, you will be waiting. |

If your organization can afford the license and needs enterprise support, certified operators, and regulatory compliance, OpenShift is hard to beat. But if you need a container platform without the cost, there are compelling alternatives.

## Free Alternatives

### OKD (The Community Distribution of Kubernetes)

[OKD](https://www.okd.io/) is the upstream community distribution of OpenShift. It is to OpenShift what Fedora is to Red Hat Enterprise Linux: the free, community-driven project that OpenShift is built on.

**Key characteristics:** Free, open-source, includes many of the same features as OpenShift.

| Feature | Details |
|---------|---------|
| **Web console** | Same OpenShift-style web console with project views, topology visualization, and developer perspective. |
| **S2I builds** | Source-to-Image builds work the same as in OpenShift. |
| **OperatorHub** | Access to the community operator catalog. |
| **Security** | Security Context Constraints and the same security model as OpenShift. |
| **CI/CD** | Tekton Pipelines and Argo CD can be installed from the operator catalog. |
| **Base OS** | Runs on Fedora CoreOS (FCOS) instead of Red Hat CoreOS (RHCOS). |

```bash
# Install OKD using the openshift-install tool
# Download the installer from https://github.com/okd-community/okd/releases

# Create an install config
./openshift-install create install-config --dir=okd-cluster

# Deploy the cluster
./openshift-install create cluster --dir=okd-cluster
```

**Best for:** Teams that want the OpenShift experience without the subscription cost. OKD is the closest thing to "free OpenShift" you can get, and knowledge transfers directly between the two platforms.

**Watch out:** OKD has a smaller community than vanilla Kubernetes, and releases can lag behind OpenShift. Enterprise support is not available, so you are responsible for troubleshooting and upgrades. The installation process is still complex, requiring similar infrastructure prerequisites as OpenShift (DNS, load balancing, dedicated nodes).

### Vanilla Kubernetes (kubeadm)

[Kubernetes](https://kubernetes.io/) itself is free and open-source. Using `kubeadm`, you can bootstrap a production-grade cluster on your own infrastructure.

**Key characteristics:** Free, maximum flexibility, no vendor opinions.

| Feature | Details |
|---------|---------|
| **Full Kubernetes API** | Every Kubernetes feature, the moment it is released upstream. |
| **Flexibility** | Choose your own CNI plugin, ingress controller, storage provider, and monitoring stack. |
| **Community** | The largest open-source community in the container orchestration space. |
| **Ecosystem** | Every Helm chart, operator, and tool targets Kubernetes first. |
| **Lightweight** | No platform overhead beyond what you choose to install. |

```bash
# Initialize a Kubernetes control plane
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Set up kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# Install a CNI plugin (Flannel in this example)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Join worker nodes
kubeadm join <control-plane-ip>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

**Best for:** Teams that want full control over their Kubernetes stack and are willing to assemble the components themselves. Vanilla Kubernetes is the foundation that every other platform builds on.

**Watch out:** You get Kubernetes and nothing else. There is no web console, no built-in CI/CD, no image registry, no opinionated security model. You must assemble your own platform from individual components (Ingress NGINX, cert-manager, Prometheus, Grafana, Harbor, Argo CD, etc.), which requires significant expertise and ongoing maintenance.

### K3s (Lightweight Kubernetes by SUSE)

[K3s](https://k3s.io/) is a certified, lightweight Kubernetes distribution built by Rancher (now part of SUSE). It packages Kubernetes into a single binary under 100 MB, replacing etcd with SQLite (or an external database) and bundling essential components.

**Key characteristics:** Free, lightweight, production-ready, single binary.

| Feature | Details |
|---------|---------|
| **Single binary** | Everything you need in one ~70 MB binary. No Java, no heavy dependencies. |
| **Built-in components** | Ships with Traefik ingress, CoreDNS, Flannel CNI, local-path storage, and a service load balancer. |
| **Low resource usage** | Runs on as little as 512 MB RAM. Ideal for edge, IoT, and resource-constrained environments. |
| **Certified Kubernetes** | Passes the CNCF conformance tests. Your kubectl skills and Helm charts work unchanged. |
| **SQLite backend** | Default datastore for single-node clusters. Supports etcd, MySQL, and PostgreSQL for HA setups. |
| **Auto-deploy manifests** | Drop YAML files into `/var/lib/rancher/k3s/server/manifests/` and K3s applies them automatically. |

```bash
# Install K3s on a server (one command)
curl -sfL https://get.k3s.io | sh -

# Check the cluster
sudo k3s kubectl get nodes

# Install K3s on a worker node
curl -sfL https://get.k3s.io | K3S_URL=https://<server-ip>:6443 \
  K3S_TOKEN=<node-token> sh -

# The token is stored at /var/lib/rancher/k3s/server/node-token on the server
```

**Best for:** Edge computing, IoT deployments, development environments, home labs, and small production workloads. K3s is arguably the easiest way to get a real, conformant Kubernetes cluster running.

**Watch out:** K3s makes trade-offs for lightness. The default SQLite backend is not suitable for large, high-availability production clusters (switch to etcd or an external database for HA). Some Kubernetes features like cloud provider integrations require additional configuration. The Traefik version bundled may lag behind the latest release.

### MicroShift (Red Hat's Edge Kubernetes)

[MicroShift](https://microshift.io/) is Red Hat's lightweight Kubernetes distribution designed for edge and resource-constrained environments. It takes the OpenShift API surface and shrinks it down to run on a single node with minimal resources.

**Key characteristics:** Free (as part of RHEL), OpenShift-compatible API, edge-focused.

| Feature | Details |
|---------|---------|
| **OpenShift API compatibility** | Supports a subset of OpenShift APIs, including Routes, so workloads can move between MicroShift and OpenShift. |
| **Minimal footprint** | Runs on devices with as little as 2 CPU cores and 2 GB RAM. |
| **Single node** | Designed for single-node deployment. No multi-node clustering. |
| **RHEL integration** | Runs on RHEL and RHEL for Edge, leveraging rpm-ostree for atomic updates. |
| **OVN-Kubernetes** | Uses the same networking stack as OpenShift. |
| **Embedded etcd** | Uses an embedded etcd instance for simplicity. |

```bash
# Install MicroShift on RHEL 9
sudo dnf install -y microshift

# Start MicroShift
sudo systemctl enable --now microshift

# Access the cluster
mkdir -p ~/.kube
sudo cat /var/lib/microshift/resources/kubeadmin/kubeconfig > ~/.kube/config

kubectl get nodes
```

**Best for:** Edge deployments that need to run OpenShift-compatible workloads on constrained hardware. If your production runs OpenShift and your edge runs MicroShift, workload manifests (including Routes) transfer between the two.

**Watch out:** MicroShift is single-node only, so it is not suitable for workloads that require high availability. The OpenShift API compatibility is partial, not all OpenShift features are available. Requires RHEL as the host OS, which has its own subscription costs (though a free developer subscription exists).

### Rancher (Multi-Cluster Kubernetes Management)

[Rancher](https://www.rancher.com/) is a free, open-source multi-cluster Kubernetes management platform by SUSE. It does not replace Kubernetes; it wraps around it, providing a unified management layer for any Kubernetes cluster.

**Key characteristics:** Free, multi-cluster management, works with any Kubernetes distribution.

| Feature | Details |
|---------|---------|
| **Multi-cluster management** | Manage K3s, RKE, EKS, AKS, GKE, and any other Kubernetes cluster from a single UI. |
| **Web UI** | Polished web console for cluster management, workload deployment, and monitoring. |
| **App catalog** | Built-in Helm chart catalog for one-click application deployment. |
| **User management** | RBAC, LDAP/AD integration, and project-based access control. |
| **Monitoring** | Integrated Prometheus and Grafana stack with preconfigured dashboards. |
| **CIS benchmarks** | Built-in security scanning against CIS Kubernetes benchmarks. |

```bash
# Install Rancher on an existing Kubernetes cluster using Helm
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

kubectl create namespace cattle-system

# Install cert-manager (required by Rancher)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace

# Install Rancher
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.example.com \
  --set replicas=3
```

**Best for:** Organizations that run multiple Kubernetes clusters and need a central management plane. Rancher is particularly strong when you run a mix of cloud-managed (EKS, AKS, GKE) and self-managed (K3s, RKE2) clusters.

**Watch out:** Rancher is a management layer, not a Kubernetes distribution. You still need to provision and maintain the underlying clusters. The Rancher server itself needs a Kubernetes cluster to run on, which adds complexity. Some advanced features (like Rancher Prime support) require a paid subscription.

### kind (Kubernetes in Docker)

[kind](https://kind.sigs.k8s.io/) runs Kubernetes clusters inside Docker containers. It was originally designed for testing Kubernetes itself but has become popular for local development and CI pipelines.

**Key characteristics:** Free, runs in Docker, fast cluster creation, CI-friendly.

| Feature | Details |
|---------|---------|
| **Docker-based** | Each Kubernetes node is a Docker container. No VMs required. |
| **Fast startup** | A single-node cluster starts in under a minute. |
| **Multi-node** | Supports multi-node clusters with separate control plane and worker containers. |
| **CI integration** | Works in GitHub Actions, GitLab CI, Jenkins, and any CI system that supports Docker. |
| **Conformant** | Full Kubernetes conformance. |
| **Configuration** | YAML-based cluster configuration for node counts, port mappings, and feature gates. |

```yaml
# kind-config.yaml -- Multi-node cluster with port mapping
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
  - role: worker
  - role: worker
```

```bash
# Create a cluster with the config above
kind create cluster --config kind-config.yaml --name dev

# Load a local Docker image into the cluster (avoids pulling from a registry)
kind load docker-image my-app:latest --name dev

# Delete the cluster
kind delete cluster --name dev
```

**Best for:** Local development, CI pipelines, and testing Kubernetes manifests. kind is the fastest way to spin up a throwaway Kubernetes cluster for testing.

**Watch out:** kind is not for production. Clusters run inside Docker containers with no persistent storage guarantees, no real networking, and no high availability. Performance depends on the host Docker daemon.

### minikube

[minikube](https://minikube.sigs.k8s.io/) is the original local Kubernetes tool. It runs a single-node Kubernetes cluster in a VM, container, or directly on bare metal.

**Key characteristics:** Free, multiple driver options, add-on ecosystem.

| Feature | Details |
|---------|---------|
| **Multiple drivers** | Docker, Podman, VirtualBox, Hyper-V, KVM2, and more. |
| **Add-ons** | Built-in add-ons for ingress, dashboard, metrics-server, registry, and other common components. |
| **Multi-cluster** | Run multiple minikube profiles simultaneously. |
| **LoadBalancer support** | `minikube tunnel` creates a real load balancer on your local machine. |
| **Dashboard** | `minikube dashboard` opens the Kubernetes Dashboard with one command. |
| **Mount support** | Mount local directories into the cluster for development workflows. |

```bash
# Start a cluster with specific resources
minikube start --cpus=4 --memory=8192 --driver=docker

# Enable common add-ons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard

# Open the Kubernetes Dashboard
minikube dashboard

# Expose a LoadBalancer service
minikube tunnel
```

**Best for:** Local development and learning Kubernetes. minikube's add-on system makes it easy to set up a feature-rich local cluster without manually installing each component.

**Watch out:** minikube is designed for development, not production. A single-node cluster cannot provide high availability. Resource consumption can be significant when running VM-based drivers. Multi-node support exists but is less mature than kind's approach.

### K0s (Zero Friction Kubernetes)

[K0s](https://k0sproject.io/) is a free, open-source Kubernetes distribution from Mirantis. It aims for zero friction, zero dependencies, and zero cost. Like K3s, it packages Kubernetes into a single binary.

**Key characteristics:** Free, single binary, zero host OS dependencies.

| Feature | Details |
|---------|---------|
| **Single binary** | No host OS dependencies beyond the kernel. Bundles all required components. |
| **Certified Kubernetes** | CNCF certified, fully conformant. |
| **Control plane isolation** | The control plane runs as a separate process, not as containers, reducing the attack surface. |
| **Konnectivity** | Built-in support for running worker nodes behind NAT or firewalls. |
| **Autopilot** | Automated, zero-downtime cluster upgrades via the k0s Autopilot controller. |
| **Flexible backend** | Supports etcd (default), SQLite, MySQL, and PostgreSQL as datastores. |

```bash
# Install k0s
curl -sSLf https://get.k0s.sh | sudo sh

# Initialize a controller node
sudo k0s install controller --single
sudo k0s start

# Get kubeconfig
sudo k0s kubeconfig admin > ~/.kube/config

# Check the cluster
kubectl get nodes
```

**Best for:** Teams that want a lightweight, production-ready Kubernetes distribution with zero host OS dependencies and automated upgrades. K0s is a strong alternative to K3s, especially when the Autopilot upgrade feature is valuable.

**Watch out:** K0s has a smaller community than K3s and fewer pre-bundled components. You will need to install your own ingress controller, storage provisioner, and other add-ons. Documentation is solid but less extensive than the K3s ecosystem.

## Head-to-Head Comparison

| Platform | Price | Production Ready | Min Resources | Multi-Node | Web Console | OpenShift Compat | Ease of Setup |
|----------|-------|-----------------|---------------|------------|-------------|-----------------|---------------|
| **OpenShift** | Paid | Yes | 16 GB+ RAM | Yes | Excellent | Full | Complex |
| **OKD** | Free | Yes | 16 GB+ RAM | Yes | Excellent | High | Complex |
| **Vanilla K8s** | Free | Yes | 2 GB RAM | Yes | Via add-on | No | Moderate |
| **K3s** | Free | Yes | 512 MB RAM | Yes | Via Rancher | No | Very Easy |
| **MicroShift** | Free* | Edge only | 2 GB RAM | No | No | Partial | Easy |
| **Rancher** | Free | Management layer | 4 GB RAM | N/A | Excellent | No | Moderate |
| **kind** | Free | No (dev/CI) | 2 GB RAM | Yes (in Docker) | No | No | Very Easy |
| **minikube** | Free | No (dev) | 2 GB RAM | Limited | Via add-on | No | Very Easy |
| **K0s** | Free | Yes | 1 GB RAM | Yes | Via add-on | No | Easy |

\* MicroShift is free but requires RHEL, which has subscription costs (free developer subscription available).

## Feature Comparison

| Feature | OpenShift | OKD | K3s | K0s | Vanilla K8s | Rancher |
|---------|-----------|-----|-----|-----|-------------|---------|
| **Built-in CI/CD** | Yes (Tekton, Argo CD) | Yes | No | No | No | No |
| **Built-in Registry** | Yes | Yes | No | No | No | No |
| **S2I Builds** | Yes | Yes | No | No | No | No |
| **OperatorHub** | Curated | Community | No | No | No | Helm catalog |
| **Routes (built-in ingress)** | Yes | Yes | Traefik | No | No | No |
| **Multi-cluster mgmt** | ACM (paid) | No | No | No | No | Yes |
| **Monitoring stack** | Built-in | Built-in | Via add-on | Via add-on | Via add-on | Built-in |
| **RBAC** | Enhanced (SCCs) | Enhanced (SCCs) | Standard | Standard | Standard | Enhanced |
| **Automated upgrades** | Yes (OTA) | Community | Manual | Autopilot | Manual | Yes |
| **Edge support** | MicroShift | No | Yes | Yes | No | Yes (K3s) |

## Choosing the Right Platform

### You need enterprise support and compliance

Stick with **Red Hat OpenShift**. No free alternative matches its certified ecosystem, long-term support, and regulatory compliance features. The cost is justified in environments where downtime or security incidents are more expensive than the subscription.

### You want the OpenShift experience without the cost

**OKD** is the obvious choice. It shares the same codebase, web console, and developer workflow as OpenShift. If your team knows OpenShift, they already know OKD. Use it for staging environments, internal projects, or organizations that do not need Red Hat's support contract.

### You need a lightweight, production-ready cluster

**K3s** is the default recommendation. One command to install, minimal resource usage, and full Kubernetes conformance. It works for everything from a Raspberry Pi home lab to production edge deployments. Pair it with Rancher for a web-based management experience.

```bash
# Full K3s cluster with Rancher in under 10 minutes
# 1. Install K3s
curl -sfL https://get.k3s.io | sh -

# 2. Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 3. Export kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# 4. Install Rancher (see Rancher section for full steps)
```

### You need a local development environment

Use **kind** if your priority is speed and CI integration, or **minikube** if you prefer a more feature-complete local cluster with add-ons. Both are free, fast, and disposable.

| Scenario | Recommendation |
|----------|---------------|
| Testing Helm charts in CI | kind |
| Daily development with dashboards | minikube |
| Reproducing production issues locally | kind (multi-node) |
| Learning Kubernetes | minikube |

### You manage multiple clusters

**Rancher** gives you a single UI to manage K3s, RKE2, EKS, AKS, GKE, and any other Kubernetes cluster. It adds user management, monitoring, and application catalogs on top of whatever Kubernetes distribution you choose.

### You run workloads on edge devices

**K3s** for general edge computing or **MicroShift** if your workloads need OpenShift API compatibility. Both are designed for constrained hardware, but they serve different ecosystems.

### You want zero dependencies and automated upgrades

**K0s** stands out with its Autopilot controller for zero-downtime automated upgrades and its zero host OS dependency model. If upgrade automation is a priority, K0s is worth evaluating alongside K3s.

## K3s Quick Start

Since K3s is the most versatile free alternative for production use, here is a walkthrough for setting up a multi-node cluster.

### Single Server with Two Workers

```bash
# On the server node
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --tls-san my-k3s-server.example.com

# Get the token for worker nodes
cat /var/lib/rancher/k3s/server/node-token

# On each worker node
curl -sfL https://get.k3s.io | K3S_URL=https://my-k3s-server.example.com:6443 \
  K3S_TOKEN=<token-from-server> sh -
```

### High Availability with External Database

```bash
# On each server node (run on 3 servers for HA)
curl -sfL https://get.k3s.io | sh -s - server \
  --datastore-endpoint="postgres://user:pass@db-host:5432/k3s" \
  --tls-san my-k3s-lb.example.com
```

### Deploying a Sample Application

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
        - name: web-app
          image: nginx:alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web-app
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-app
                port:
                  number: 80
```

```bash
# Apply the manifests
kubectl apply -f deployment.yaml

# Verify the deployment
kubectl get pods -l app=web-app
kubectl get ingress
```

### Useful K3s Commands

| Action | Command |
|--------|---------|
| Check cluster status | `sudo k3s kubectl get nodes` |
| View K3s logs | `sudo journalctl -u k3s -f` |
| Uninstall K3s (server) | `sudo /usr/local/bin/k3s-uninstall.sh` |
| Uninstall K3s (agent) | `sudo /usr/local/bin/k3s-agent-uninstall.sh` |
| Use standard kubectl | `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml` |
| List installed Helm charts | `sudo k3s kubectl get helmcharts -A` |
| Check Traefik ingress | `sudo k3s kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik` |

## Migrating from OpenShift to Kubernetes

If you are transitioning from OpenShift to a free alternative, here are the key differences to be aware of.

| OpenShift Concept | Kubernetes Equivalent |
|-------------------|----------------------|
| Route | Ingress (with an ingress controller like Traefik or NGINX) |
| DeploymentConfig | Deployment (standard Kubernetes resource) |
| BuildConfig / S2I | External CI/CD (GitHub Actions, GitLab CI, Tekton, etc.) |
| ImageStream | Direct container image references |
| Project | Namespace |
| Security Context Constraints | Pod Security Standards / Pod Security Admission |
| OperatorHub | Helm charts + OLM (Operator Lifecycle Manager) |
| `oc` CLI | `kubectl` (the `oc` CLI is a superset of `kubectl`) |

The most common migration pain points are **Routes** (replace with Ingress resources), **S2I builds** (replace with Dockerfiles and a CI pipeline), and **Security Context Constraints** (review and adapt pod security settings).

```yaml
# OpenShift Route
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: my-app
spec:
  host: my-app.example.com
  to:
    kind: Service
    name: my-app

# Kubernetes Ingress (equivalent)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  rules:
    - host: my-app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 8080
```

## Summary

Red Hat OpenShift remains the gold standard for enterprise Kubernetes. Its integrated CI/CD, certified operator ecosystem, security model, and long-term support justify the cost for organizations that need compliance and vendor-backed support. But the moment budget constraints come into play, or you simply need a Kubernetes platform without the enterprise overhead, the free alternatives deliver.

**K3s** is the most practical general-purpose replacement. It installs in seconds, runs on anything from a Raspberry Pi to a production server, and passes every Kubernetes conformance test. For teams that specifically want the OpenShift developer experience, **OKD** is the closest free equivalent. **Rancher** fills the management gap if you run multiple clusters, and **kind** and **minikube** cover local development and CI workflows.

The Kubernetes ecosystem is rich enough that you can assemble a platform rivaling OpenShift's feature set entirely from free, open-source components. It requires more effort, more decisions, and more operational expertise, but the building blocks are all there. Start with K3s, add Rancher for management, install Argo CD for GitOps, deploy Harbor for a container registry, and set up Prometheus and Grafana for monitoring. You will have a production-grade container platform without a single license fee.

> **Other free Kubernetes distributions worth knowing about:** This post focused on the most established options, but the cloud-native ecosystem is broader than what we covered. A few notable projects that did not make the main list:
>
> - **[RKE2](https://docs.rke2.io/)** -- Rancher's next-generation Kubernetes distribution focused on security and compliance. CIS-hardened out of the box. Free and open-source.
> - **[Talos Linux](https://www.talos.dev/)** -- A minimal, immutable Linux OS designed specifically for Kubernetes. The entire OS is managed via an API, with no SSH access. Ideal for security-conscious deployments.
> - **[Kubespray](https://kubespray.io/)** -- Ansible-based Kubernetes deployment tool that works on bare metal, AWS, GCE, Azure, and OpenStack. More flexible than kubeadm for automated, repeatable deployments.
> - **[MicroK8s](https://microk8s.io/)** -- Canonical's lightweight Kubernetes distribution, packaged as a snap. Single-command install on Ubuntu with add-on support for Istio, Knative, and GPU workloads.
> - **[Harvester](https://harvesterhci.io/)** -- Open-source hyperconverged infrastructure (HCI) solution that runs VMs and Kubernetes workloads side by side. Built on K3s and KubeVirt.
> - **[Flatcar Container Linux](https://flatcar-linux.org/)** -- A community-maintained fork of CoreOS Container Linux, designed as a minimal, immutable OS for running containers at scale.
>
> Each of these fills a specific niche. If none of the main recommendations fit your requirements, one of these might.
