PRA-Alexia — Infrastructure as Code

Déploiement automatisé et reproductible d'une architecture sécurisée dans le cadre d'un Plan de Reprise d'Activité (PRA), réalisé avec Terraform, Ansible et HashiCorp Vault sur Proxmox VE.

<<<<<<< HEAD
Déploiement automatisé et reproductible d'une architecture sécurisée dans le cadre d'un **Plan de Reprise d'Activité (PRA)**, réalisé avec **Terraform**, **Ansible** et **HashiCorp Vault** sur **Proxmox VE**.
=======
>>>>>>> dd7244ecb582318f0bdcf7a3bde2212432920f06

> Projet de fin d'année — Bac+4 Architecte Cybersécurité.

---


<<<<<<< HEAD
Ce dépôt contient l'ensemble du code d'infrastructure permettant de reconstruire *from scratch* les composants critiques d'un système d'information, dans une démarche de PRA. Chaque service est provisionné (Terraform), configuré (Ansible) et ses secrets sont injectés dynamiquement depuis Vault, sans qu'aucune donnée sensible ne figure dans le dépôt.

L'objectif : à partir d'un hôte Proxmox vierge et d'un kit d'amorçage minimal, régénérer l'infrastructure complète, restaurer les données depuis les sauvegardes externalisées, et rétablir la supervision.

---

## 2. Composants déployés

| Composant | Rôle | Type | VLAN |
|-----------|------|------|------|
| pfSense | Pare-feu, segmentation, VPN sortant | VM (template cloné) | Passerelle multi-VLAN |
| HashiCorp Vault | Coffre-fort de secrets (backend Raft, AppRole) | LXC | Vlan50 |
| Nagios XI | Supervision, centralisation des alertes | LXC | Vlan50 |
| Graylog | Centralisation des logs (MongoDB + OpenSearch) | LXC | Vlan50 |
| MariaDB | Base de données Nextcloud (dédiée) | LXC | Vlan50 |
| Nextcloud | Stockage de fichiers, base distante | LXC | Vlan40 |

---

## 3. Architecture

### Segmentation réseau

| Zone | Bridge | Sous-réseau |
|------|--------|-------------|
| DMZ | Vlan20 | 192.168.20.0/24 |
| LAN serveurs | Vlan30 | 192.168.30.0/24 |
| Administration | Vlan40 | 192.168.40.0/24 |
| Supervision | Vlan50 | 192.168.50.0/24 |

Chaque VLAN est routé et filtré par pfSense. Les flux inter-VLAN (par exemple Nextcloud en Vlan40 vers sa base MariaDB en Vlan50 sur le port 3306, ou la supervision NCPA vers le Vlan40 sur le port 5693) font l'objet de règles explicites.

### Gestion des secrets

Tous les secrets (mots de passe, tokens, clés) sont stockés dans **HashiCorp Vault** (moteur KV v2). Les déploiements s'authentifient via **AppRole** et récupèrent les secrets à la volée. Seul un fichier `.env` local (kit d'amorçage), non versionné, contient le secret zéro permettant de contacter Vault.

### Supervision

L'agent **NCPA** est installé sur chaque composant (Graylog, MariaDB, Nextcloud, Vault). Nagios interroge les agents pour surveiller les services et les ressources (CPU, mémoire, disque). Les logs applicatifs (dont ceux de Nagios) sont centralisés vers Graylog via rsyslog.

### Sauvegarde et restauration

Les données critiques (base MariaDB, configuration Nextcloud, dumps MongoDB de Graylog, configurations Nagios) sont sauvegardées et externalisées vers un **NAS Synology** en SFTP, avec politique de rétention. La restauration est automatisée : au redéploiement, les scripts récupèrent la dernière sauvegarde et réinjectent les données.

---

## 4. Prérequis

- Proxmox VE 8.x
- Terraform >= 1.5 (providers `bpg/proxmox`, `hashicorp/vault`)
- Ansible (collections `community.general`, `community.proxmox`)
- HashiCorp Vault initialisé et déverrouillé
- Compte de service Proxmox (token API + accès SSH)
- Utilitaires : `sshpass`, `jq`, `passlib`

---

## 5. Structure du dépôt

```
=======


1. Présentation

Ce dépôt contient l'ensemble du code d'infrastructure permettant de reconstruire from scratch les composants critiques d'un système d'information, dans une démarche de PRA. Chaque service est provisionné (Terraform), configuré (Ansible) et ses secrets sont injectés dynamiquement depuis Vault, sans qu'aucune donnée sensible ne figure dans le dépôt.

L'objectif : à partir d'un hôte Proxmox vierge et d'un kit d'amorçage minimal, régénérer l'infrastructure complète, restaurer les données depuis les sauvegardes externalisées, et rétablir la supervision.


2. Composants déployés

ComposantRôleTypeVLANpfSensePare-feu, segmentation, VPN sortantVM (template cloné)Passerelle multi-VLANHashiCorp VaultCoffre-fort de secrets (backend Raft, AppRole)LXCVlan50Nagios XISupervision, centralisation des alertesLXCVlan50GraylogCentralisation des logs (MongoDB + OpenSearch)LXCVlan50MariaDBBase de données Nextcloud (dédiée)LXCVlan50NextcloudStockage de fichiers, base distanteLXCVlan40


3. Architecture

Segmentation réseau

ZoneBridgeSous-réseauDMZVlan20192.168.20.0/24LAN serveursVlan30192.168.30.0/24AdministrationVlan40192.168.40.0/24SupervisionVlan50192.168.50.0/24

Chaque VLAN est routé et filtré par pfSense. Les flux inter-VLAN (par exemple Nextcloud en Vlan40 vers sa base MariaDB en Vlan50 sur le port 3306, ou la supervision NCPA vers le Vlan40 sur le port 5693) font l'objet de règles explicites.

Gestion des secrets

Tous les secrets (mots de passe, tokens, clés) sont stockés dans HashiCorp Vault (moteur KV v2). Les déploiements s'authentifient via AppRole et récupèrent les secrets à la volée. Seul un fichier .env local (kit d'amorçage), non versionné, contient le secret zéro permettant de contacter Vault.

Supervision

L'agent NCPA est installé sur chaque composant (Graylog, MariaDB, Nextcloud, Vault). Nagios interroge les agents pour surveiller les services et les ressources (CPU, mémoire, disque). Les logs applicatifs (dont ceux de Nagios) sont centralisés vers Graylog via rsyslog.

Sauvegarde et restauration

Les données critiques (base MariaDB, configuration Nextcloud, dumps MongoDB de Graylog, configurations Nagios) sont sauvegardées et externalisées vers un NAS Synology en SFTP, avec politique de rétention. La restauration est automatisée : au redéploiement, les scripts récupèrent la dernière sauvegarde et réinjectent les données.


4. Prérequis


Proxmox VE 8.x
Terraform >= 1.5 (providers bpg/proxmox, hashicorp/vault)
Ansible (collections community.general, community.proxmox)
HashiCorp Vault initialisé et déverrouillé
Compte de service Proxmox (token API + accès SSH)
Utilitaires : sshpass, jq, passlib



5. Structure du dépôt

>>>>>>> dd7244ecb582318f0bdcf7a3bde2212432920f06
.
├── terraform/          # Provisioning des VM/LXC (un dossier par composant)
│   ├── mariadb/
│   ├── graylog/
│   ├── nextcloud/
│   └── ...
├── ansible/            # Playbooks de configuration des services
│   ├── deploy-mariadb.yml
│   ├── deploy-graylog.yml
│   ├── deploy-nextcloud.yml
│   ├── restore-nextcloud.yml
│   └── inventory-*.ini
├── deploy-*.sh         # Scripts d'orchestration (Vault → Terraform → Ansible)
├── backup_*.sh         # Scripts de sauvegarde vers le NAS
└── README.md
<<<<<<< HEAD
```

---

## 6. Déploiement

Chaque composant se déploie via son script d'orchestration, qui enchaîne : authentification Vault, récupération des secrets, provisioning Terraform, puis configuration Ansible.

```bash
# Charger le kit d'amorçage
cp .env.example .env   # puis renseigner les accès Vault

# Exemple : déployer Nextcloud + sa base MariaDB, avec restauration
./deploy-nextcloud.sh
```

Le déploiement Nextcloud illustre le cycle complet : création du LXC MariaDB (base dédiée), création du LXC Nextcloud, installation, puis restauration des données depuis la dernière sauvegarde du NAS.

---

## 7. Sécurité des secrets

- **Aucun secret dans le dépôt** — exclusion stricte via `.gitignore` (`.env`, `*.snap`, `*.sql.gz`, backups, états Terraform).
- Secrets centralisés dans **HashiCorp Vault** et récupérés au moment du déploiement.
- Authentification des déploiements via **AppRole** (identifiants à durée de vie limitée).
- Le fichier `.env` (accès Vault) reste strictement local et n'est jamais versionné.

---

## 8. Auteurs
=======


6. Déploiement

Chaque composant se déploie via son script d'orchestration, qui enchaîne : authentification Vault, récupération des secrets, provisioning Terraform, puis configuration Ansible.
>>>>>>> dd7244ecb582318f0bdcf7a3bde2212432920f06

bash# Charger le kit d'amorçage
cp .env.example .env   # puis renseigner les accès Vault

# Exemple : déployer Nextcloud + sa base MariaDB, avec restauration
./deploy-nextcloud.sh

Le déploiement Nextcloud illustre le cycle complet : création du LXC MariaDB (base dédiée), création du LXC Nextcloud, installation, puis restauration des données depuis la dernière sauvegarde du NAS.


7. Sécurité des secrets


Aucun secret dans le dépôt — exclusion stricte via .gitignore (.env, *.snap, *.sql.gz, backups, états Terraform).
Secrets centralisés dans HashiCorp Vault et récupérés au moment du déploiement.
Authentification des déploiements via AppRole (identifiants à durée de vie limitée).
Le fichier .env (accès Vault) reste strictement local et n'est jamais versionné.



8. Auteurs


Prénom NOM
Prénom NOM (binôme)
