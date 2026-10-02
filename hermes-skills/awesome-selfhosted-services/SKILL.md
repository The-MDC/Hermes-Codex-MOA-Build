---
name: awesome-selfhosted-services
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


# awesome-selfhosted/awesome-selfhosted Integration for Hermes Agent

## Overview
This skill integrates **awesome-selfhosted/awesome-selfhosted** into Hermes Agent, providing access to 316,890+ starred list of Free Software network services and web applications for self-hosting — perfect for deploying agent infrastructure, tools, and services on your own servers.

## Why Awesome-Selfhosted?
- **316,890+ stars** — Massive community-vetted collection
- **Free Software only** — Open source, libre, no vendor lock-in
- **Network services & web apps** — Everything from databases to AI platforms
- **Self-hosted focus** — Run on your own infrastructure, not SaaS
- **Production-ready** — Battle-tested in real deployments
- **Categorized** — Easy navigation by service type

## What's Included
### Analytics
- Umami, Plausible, GoatCounter, Matomo, Ackee
- Grafana, Prometheus, InfluxDB, TimescaleDB
- Elasticsearch, Kibana, Loki, Tempo

### Archiving & Digital Preservation
- ArchiveBox, Wallabag, Medusa, Paperless-ngx
- DSpace, Greenstone, Alfresco Community
- KnowledgeBase, Wiki.js, BookStack

### Automation
- Huginn, n8n, Node-RED, Activepieces
- Apache Airflow, Argo Workflows, Temporal.io
- Apache NiFi, Prefect, Dagster

### Backup
- Restic, BorgBackup, Duplicati, UrBackup
- Snapraid, Timeshift, BackupPC
- Minio, Velero, Velero

### Blogging Platforms
- Write.as, Plume, WriteFreely, Ghost
- WordPress, Write.as, Plume, WriteFreely

### Booking & Scheduling
- BookStack, Calendly self-hosted, SimplyBook.me
- MRBS, Booked, Room Booking System

### Communication
- **Email**: Mailu, Mail-in-a-Box, Modoboa, iRedMail
- **Chat**: Matrix, Rocket.Chat, Zulip, Mattermost
- **VoIP**: FreeSWITCH, Asterisk, Kamailio, Jitsi Meet
- **Forums**: Discourse, Flarum, phpBB, Vanilla
- **Video Conferencing**: Jitsi Meet, BigBlueButton, Whereby
- **XMPP**: Prosody, Ejabberd, Prosody

### Content Management Systems (CMS)
- WordPress, Ghost, Strapi, Directus
- Drupal, Joomla, Grav, Kirby
- Contentful, Sanity, Netlify CMS

### Customer Relationship Management (CRM)
- SuiteCRM, EspoCRM, Zurmo, OroCRM
- Salesforce Community Edition, Vtiger CRM

### Database Management
- PostgreSQL, MySQL, MariaDB, MongoDB
- Redis, Cassandra, CouchDB, RethinkDB
- Elasticsearch, Neo4j, OrientDB, ArangoDB

### DevOps Tools
- GitLab, Gitea, Drone CI, Jenkins
- Kong, Traefik, Envoy, HAProxy
- Nomad, Consul, Vault, Docker Registry

### Document Management
- Paperless-ngx, Mayan EDMS, Alfresco
- LogicalDOC, OpenKM, Nuxeo
- OnlyOffice, ONLYOFFICE, Docspell

### E-commerce
- WooCommerce, Shopware, Magento Open Source
- PrestaShop, OpenCart, BigCommerce
- Saleor, Shopify, Medusa

### Identity & Access Management
- Keycloak, Authelia, OAuth2 Proxy, CAS
- GLPI, FusionAuth, LoginRadius, Auth0

### Internet of Things (IoT)
- ThingsBoard, Node-RED, Eclipse Kura
- Home Assistant, Domoticz, OpenHAB
- Blynk, Cayenne, Watson IoT

### Knowledge Management Tools
- Wiki.js, BookStack, DokuWiki, TiddlyWiki
- Wikimedia, Confluence, Notion self-hosted
- Documize, XWiki, Standard Notes

### Learning & Courses
- Moodle, Open edX, Canvas, ILIAS
- Chamilo, Sakai, Fronter, Google Classroom self-hosted

### Manufacturing
- Odoo, ERPNext, Tryton, Dolibarr
- Apache OFBiz, MantisBT, WebERP

### Media
- Peertube, Jellyfin, Plex, Emby
- Ampere, Vidhub, Radarr, Sonarr
- Lidarr, Bazarr, Overseerr

### Monitoring
- Prometheus, Grafana, InfluxDB, TimescaleDB
- VictoriaMetrics, Netdata, Zabbix
- Nagios, Icinga, Sensu, Telegraf

### Multimedia
- Jellyfin, Plex, Emby, Ampere
- Subsonic, Airsonic, Funkwhale, Navidrome
- Kast, Plex, Jellyfin, Emby

### Productivity
- OnlyOffice, ONLYOFFICE, CryptPad
- Nextcloud, owncloud, SOGo
- Turtl, Standard Notes, Joplin

### Programming Language Tools
- GitLab, Gitea, SourceHut, Phabricator
- SonarQube, CodeClimate, LGTM
- Gerrit, Phabricator, RhodeCode

### Project Management
- Taiga, Wekan, OpenProject, Redmine
- Azure DevOps self-hosted, Phabricator
- Asana self-hosted, Trello self-hosted

### Security & Privacy
- Vault, WireGuard, Pi-hole, AdGuard Home
- OpenVAS, Lynis, OSSEC, Fail2Ban
- ModSecurity, Cloudflare, Sucuri

### Streaming
- Owncast, PeerTube, Icecast, Shoutcast
- RTMP server, HLS, MPEG-DASH
- FFmpeg, GStreamer, VLC

### Translation
- Weblate, Zanata, Pootle, Lokalise
- Apertium, OmegaT, Virtaal, Poedit

### VPN
- WireGuard, OpenVPN, StrongSwan, SoftEther
- ZeroTier, Tailscale, OpenConnect
- Pritunl, AzireVPN, Mullvad

### Web Servers
- Nginx, Apache, Caddy, Lighttpd
- Envoy, Traefik, HAProxy, Varnish
- IIS, LiteSpeed, OpenLiteSpeed

### Wiki & Knowledge Base
- Wiki.js, BookStack, DokuWiki, TiddlyWiki
- Wikimedia, Confluence, Notion self-hosted
- XWiki, Standard Notes, Documize

## Installation

```bash
# No installation required — it's a reference guide
# Access via: https://awesome-selfhosted.net/ or local clone

# Optional: Clone for offline access
git clone https://github.com/awesome-selfhosted/awesome-selfhosted.git
cd awesome-selfhosted

# Or use the website directly
# https://awesome-selfhosted.net/
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  awesome-selfhosted-services: true

# Environment variables
export AWESOME_SELFHOSTED_PATH="$HOME/.hermes/resources/awesome-selfhosted"  # if cloned locally
export AWESOME_SELFHOSTED_DEFAULT_CATEGORY="databases"  # analytics | cms | databases | devops | etc.
export AWESOME_SELFHOSTED_CACHE_DIR="$HOME/.hermes/cache/awesome-selfhosted"
```

## Usage

### Finding Services

```python
from hermes_tools import awesomeselfhosted

# Get services by category
services = awesomeselfhosted.get_services_by_category(
    category="databases",
    license="MIT",  # Optional filter
    language="python"  # Optional filter
)

# Or via CLI
awesome-selfhosted databases --license MIT --language python

# Search for specific functionality
services = awesomeselfhosted.search(
    query="time series database",
    category="databases"
)

# Get service details
service_details = awesomeselfhosted.get_service_details(
    name="postgresql",
    category="databases"
)
```

### Hermes Agent Commands

```bash
# List available categories
hermes awesome-selfhosted list-categories

# Find databases for agent memory
hermes awesome-selfhosted search --query "vector database" --category "databases"

# Get PostgreSQL details for agent storage
hermes awesome-selfhosted info --name postgresql --category databases

# Find monitoring tools for agent observability
hermes awesome-selfhosted search --query "application performance monitoring" --category monitoring

# Get self-hosted AI platform options
hermes awesome-selfhosted search --query "LLM platform" --category "ai-ml-platforms"

# Deploy a service using the info
hermes awesome-selfhosted deploy --name postgresql --version 15 --port 5432
```

### Example Workflows

#### Deploy Agent Memory Database
```bash
# Find suitable vector database
hermes awesome-selfhosted search --query "vector database pgvector" --category databases

# Get PostgreSQL+pgvector details
hermes awesome-selfhosted info --name postgresql --category databases

# Deploy with Hermes
hermes awesome-selfhosted deploy --name postgresql --extensions "postgis,pgvector" --port 5432
```

#### Set Up Agent Monitoring Stack
```bash
# Find monitoring tools
hermes awesome-selfhosted search --query "prometheus grafana" --category monitoring

# Deploy monitoring stack
hermes awesome-selfhosted deploy --name prometheus --port 9090
hermes awesome-selfhosted deploy --name grafana --port 3000
```

#### Create Agent Development Environment
```bash
# Get self-hosted GitLab for code hosting
hermes awesome-selfhosted info --name gitlab --category devops

# Get self-hosted registry for container images
hermes awesome-selfhosted info --name registry --category devops

# Deploy development stack
hermes awesome-selfhosted deploy --name gitlab --port 8080
hermes awesome-selfhosted deploy --name registry --port 5000
```

## Benefits
- **Infrastructure as code** — Find and deploy services via natural language
- **Vendor independence** — Free Software alternatives to SaaS
- **Production guidance** — Real deployment experiences from community
- **Security-focused** — Many services include encryption, auth, audit
- **Cost-effective** — No licensing fees, run on your own hardware
- **Customizable** — Access source code to modify for agent needs

## Verification

```bash
# Check Hermes recognizes the skill
hermes doctor

# Test category listing
hermes awesome-selfhosted list-categories

# Test search functionality
hermes awesome-selfhosted search --query "redis" --category databases

# Test service info
hermes awesome-selfhosted info --name postgres --category databases

# Test deployment guidance
hermes awesome-selfhosted deploy --name postgres --help
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Service not found | Check spelling or try different category |
| Category not recognized | Use `list-categories` to see all options |
| Deployment fails | Check prerequisites in service documentation |
| License filter too restrictive | Remove or broaden license filter |
| Language mismatch | Try different language or remove filter |
| Version compatibility issues | Check service-specific version notes |

## References
- Original repo: https://github.com/awesome-selfhosted/awesome-selfhosted
- Website: https://awesome-selfhosted.net/
- License: Other (CC0-1.0 or similar for the list)
- Star count: 316,890+ (as of 2026)
- Fork count: 14,895+
- Last updated: Active maintenance
- Categories: 20+ service categories with subcategories