---
layout: post
title: Unraid - Unleash Your Hardware
date: 2026-01-18 00:00:00 -0500
categories: [Unraid, Hardware, Storage, NAS]
tags: [ZFS, BTRFS, XFS, RAID, Docker, Virtualization, NAS, ProtonVPN]
description: Read everything important I know about Unraid
---

# Unraid - Unleash Your Hardware Potential
Unraid is a Bootrap OS that allows you to run multiple operating systems on a single server.
It boots usually from a USB drive, so the configuration is stored on the USB drive.
Unraid is designed to be easy to use and manage, making it a popular choice for home
servers and small business servers.

## Key Features of Unraid
- **Flexible Storage Management**: Unraid allows you to mix and match different sizes and types
  of hard drives in a single array. It supports various file systems, including XFS, BTRFS, and ZFS.
- **Data Protection**: Unraid uses a parity-based system to protect your data. You can have one or two
  parity drives, which can recover data in case of drive failure.
- **Docker Support**: Unraid has built-in support for Docker containers, allowing you to run
  applications in isolated environments.
- **Virtualization**: Unraid supports KVM-based virtualization, enabling you to run multiple
  virtual machines on your server.
- **User-Friendly Interface**: Unraid has a web-based interface that makes it easy to manage your server,
  monitor system health, and configure settings.
- **Kubernetes Support**: Unraid supports Kubernetes not directly, the recommendet way is to setup up a virtual machine and install the K3s in a VM.

## Fileformats
- XFS (eXtensible File System) - recommended
- BTRFS (B-Tree File System)
- ZFS (Zettabyte File System) - hardly to expand storage size

## RAID
- RAID 0 (Striping)
- RAID 1 (Mirroring)
- RAID 5 (Parity)
- RAID 6 (Parity)

## Shares
In Unraid, "shares" are user-defined folders on your server that allow you to organize and manage your files across multiple drives. With shares, you can group data by purpose (such as "Movies", "Backups", or "Documents") and control security and access settings per share. Unraid automatically distributes the data within each share according to your chosen settings, maximizing storage flexibility while making your files accessible over the network using SMB, NFS, or AFP protocols. This makes it easy to create public, private, or secure shares for different users or devices in your environment.

## Docker
Unraid is a server OS with built‑in Docker support and a web UI, so managing containers on it is similar in functionality to using Docker Desktop, but designed for a server/NAS environment.

You can install nearly every docker image, by default docker hub is linked as docker image repository, beside other sites.
 
## VM
Unraid makes it easy to configure and manage virtual machines (VMs) using its built-in web interface. You can create VMs for various operating systems, including Windows, Linux, and others, with support for assigning specific CPU cores, memory, USB devices, and network settings. Unraid allows for passthrough of hardware components, such as GPUs (GPU passthrough) and PCI devices, enabling you to run demanding applications or even gaming workloads inside a VM. Disk images for VMs can be stored on your array or a cache drive, and you can use ISO files or existing virtual disks to install operating systems. The flexibility and granular control Unraid provides makes it an excellent platform for running and experimenting with multiple VMs on a single server.

## VPN via Docker
ProtonVPN can be run in Unraid as a Docker container, allowing you to route the traffic of other containers through a secure VPN connection. Typically, you set up a ProtonVPN client container (such as `bubuntux/protonvpn` or similar OpenVPN-based images) and configure it with your ProtonVPN credentials. 

To have other containers communicate via the VPN, you configure those containers to use the ProtonVPN container's network stack by setting the `--network=container:<protonvpn-container-name>` option when creating them. This means all network traffic from these containers will be routed through the secure ProtonVPN connection, hiding their traffic from your regular network.

This approach is ideal for torrent clients or privacy-sensitive applications where you want to ensure all traffic flows through the VPN, even if the VPN container restarts or drops its connection. Be sure to use containers that support this networking mode and check their documentation for further integration details.

 