# PRA-Alexia — Infrastructure as Code

Déploiement automatisé et reproductible d'une architecture sécurisée dans le cadre d'un Plan de Reprise d'Activité (PRA), réalisé avec Terraform et Ansible sur Proxmox VE.

Projet de fin d'année — Bac+4 Architecte Cybersécurité.

## 1. Présentation

Ce dépôt contient le code d'infrastructure permettant de reconstruire "from scratch" les composants critiques du site primaire, dans une démarche de PRA.

| Composant | Rôle | Type |
|-----------|------|------|
| pfSense | Pare-feu, VPN sortant | VM (ISO) |
| MariaDB | Base de données | LXC |
| Graylog | Centralisation des logs | LXC |

## 2. Architecture

### Segmentation réseau (site primaire)

| Zone | Bridge | Sous-réseau |
|------|--------|-------------|
| DMZ | Vlan20 | 192.168.20.0/24 |
| LAN serveurs | Vlan30 | 192.168.30.0/24 |
| Admin | Vlan40 | 192.168.40.0/24 |
| Supervision | Vlan50 | 192.168.50.0/24 |

### Interconnexion des sites

Un tunnel WireGuard relie le site primaire au site secondaire, transportant la réplication des sauvegardes et l'acheminement des logs.

## 3. Prérequis

- Proxmox VE 8.x
- Terraform >= 1.5
- Ansible + collection community.hashi_vault
- HashiCorp Vault déverrouillé
- Clé SSH autorisée sur Proxmox

## 4. Structure du dépôt

\`\`\`
.
├── terraform/     # provisioning des VMs/LXC
├── ansible/       # configuration des services
├── scripts/       # scripts de déploiement
├── configs/       # configurations exportées
└── docs/          # documentation
\`\`\`

## 5. Sécurité des secrets

- Aucun secret dans le dépôt (exclu via .gitignore)
- Secrets récupérés depuis HashiCorp Vault au déploiement
- Accès Vault chargés depuis un fichier .env local non versionné

## 6. Auteurs

- Prénom NOM
- Prénom NOM (binôme)
