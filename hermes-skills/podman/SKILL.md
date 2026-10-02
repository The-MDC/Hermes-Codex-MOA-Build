---
name: podman
description: """"
version: 1.0.0
author: "unknown"
license: "MIT"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [automatically-portled]
    category: general
    related_skills: []
---

# podman Skill

## Description
Podman (the POD MANager) is a tool for managing containers and images, volumes mounted into those containers, and pods made from groups of containers.
Podman runs containers on Linux, but can also be used on Mac and Windows systems using a Podman-managed virtual machine.
Podman is based on libpod, a library for container lifecycle management.

## Why This Skill is Valuable
- Provides container and pod management without requiring a daemon (unlike Docker)
- Supports multiple container image formats (OCI and Docker images)
- Full management of container lifecycle (creation, running, checkpointing, restoring, removal)
- Can be used to manage containers and pods in development and production
- Rootless containers for improved security
- Compatible with Docker CLI (podman docker alias)

## Key Features
- Manage OCI containers and pods
- Pull, create, push container images
- Run containers with various options (detached, interactive, ports, volumes, etc.)
- Checkpoint and restore containers (via CRIU)
- Manage pods (groups of containers)
- Rootless containers
- Docker-compatible CLI (via podman-docker package or alias)
- Image signing and verification
- Volume management
- Network management

## Usage
This skill provides access to Podman's container management capabilities that can be used to:
- Develop and test containerized applications
- Manage container images and registries
- Run containers in development and production environments
- Orchestrate multi-container applications with pods
- Integrate with CI/CD pipelines for container workflows
- Manage container lifecycles (start, stop, restart, remove)
- Inspect container logs and statistics
- Execute commands inside running containers

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  podman: true
```