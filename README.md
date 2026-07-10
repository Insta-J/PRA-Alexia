# PRA-Alexia — Infrastructure as Code

Déploiement automatisé et reproductible d'une architecture sécurisée dans le cadre d'un **Plan de Reprise d'Activité (PRA)**, réalisé avec **Terraform**, **Ansible** et **HashiCorp Vault** sur **Proxmox VE**.

> Projet de fin d'année — Bac+4 Architecte Cybersécurité.

---

## 1. Présentation

Ce dépôt contient l'ensemble du code d'infrastructure permettant de reconstruire *from scratch* les composants critiques d'un système d'information, dans une démarche de PRA. Chaque service est provisionné (Terraform), configuré (Ansible) et ses secrets sont injectés dynamiquement depuis Vault, sans qu'aucune donnée sensible ne figure dans le dépôt.

L'objectif : à partir d'un hôte Proxmox vierge et d'un kit d'amorçage minimal, régénérer l'infrastructure complète, restaurer les données depuis les sauvegardes externalisées, et rétablir la supervision.

---

## 2. Composants déployés

| Composant | Rôle | Type | VLAN |
|-----------|------|------|------|
| pfSense | Pare-feu, segmentation, VPN sortant | VM (template cloné) | Passerelle multi-VLAN |
| HashiCorp Vault | Coffre-fort de secrets (backend Raft, AppRole) | LXC | Vlan50 |
| Nagios XI | Supervision, centralisation des alertes | LXC | Vlan50 |
| Graylog | Centralisation des logs (MongoDB + OpenSearch) + SIEM | LXC | Vlan50 |
| MariaDB | Base de données Nextcloud (dédiée) | LXC | Vlan50 |
| Nextcloud | Stockage de fichiers, base distante | LXC | Vlan40 |

---

## 3. Architecture

### Hyperviseurs

L'architecture repose sur deux hyperviseurs Proxmox, répartis sur deux sites distincts :

- **Proxmox 1 — Site primaire** : héberge les services de production (pare-feu, base de données, supervision, centralisation des logs).
- **Proxmox 2 — Site secondaire** : joue le rôle d'endpoint VPN, de dépôt de sauvegardes externalisées et de récepteur de logs.

### Segmentation réseau

| Zone | Bridge | Sous-réseau |
|------|--------|-------------|
| Utilisateurs | Vlan20 | 192.168.20.0/24 |
| Administrations | Vlan30 | 192.168.30.0/24 |
| DMZ | Vlan40 | 192.168.40.0/24 |
| Serveurs | Vlan50 | 192.168.50.0/24 |

Chaque VLAN est routé et filtré par pfSense. Les flux inter-VLAN (par exemple Nextcloud en Vlan40 vers sa base MariaDB en Vlan50 sur le port 3306, ou la supervision NCPA vers le Vlan40 sur le port 5693) font l'objet de règles explicites.

### Gestion des secrets

Tous les secrets (mots de passe, tokens, clés) sont stockés dans **HashiCorp Vault** (moteur KV v2). Les déploiements s'authentifient via **AppRole** et récupèrent les secrets à la volée. Seul un fichier `.env` local (kit d'amorçage), non versionné, contient le secret zéro permettant de contacter Vault.

### Supervision et centralisation des logs

L'agent **NCPA** est installé sur chaque composant (Graylog, MariaDB, Nextcloud, Vault). Nagios interroge les agents pour surveiller les services et les ressources (CPU, mémoire, disque). En parallèle, les logs applicatifs et système (Nagios, pfSense, Duplicati, etc.) sont centralisés vers **Graylog** via rsyslog.

### Détection de sécurité (SIEM)

Au-delà de la simple centralisation, Graylog assure un rôle de **SIEM**. Il permet de définir des alertes personnalisées à partir des logs collectés : par exemple, surveiller les journaux de connexion de pfSense afin de détecter une tentative de force brute (répétition d'échecs d'authentification) et de la remonter en temps réel.

### Sauvegarde et restauration

Les données critiques (base MariaDB, configuration Nextcloud, dumps MongoDB de Graylog, configurations Nagios), ainsi que les LXC et VM Proxmox, sont sauvegardées vers un **NAS Synology** en SFTP, avec une politique de rétention. La restauration est automatisée : au redéploiement, les scripts récupèrent la dernière sauvegarde et réinjectent les données.

Les sauvegardes du NAS primaire sont ensuite **externalisées** vers un second NAS, situé sur le site secondaire, à travers le tunnel chiffré inter-sites. On obtient ainsi une double copie géographiquement séparée, conforme à la logique d'un PRA.

### Interconnexion des sites

Un tunnel **WireGuard** relie les deux sites. Le client (initiateur) est porté par pfSense sur le site primaire, le serveur se trouvant côté site secondaire. Ce tunnel transporte la réplication des sauvegardes et l'acheminement des logs vers le site distant, le tout de manière chiffrée.

---

## 4. Prérequis

### Environnement Proxmox

- Proxmox VE 8.x sur les deux sites
- Un **template pfSense vierge** (VM clonable), servant de base au déploiement du pare-feu
- Un **template LXC Ubuntu 22.04**, servant de base aux conteneurs de services (Vault, Nagios, Graylog, MariaDB, Nextcloud)
- Compte de service Proxmox (token API + accès SSH)

### Outils d'automatisation

- Terraform >= 1.5 (providers `bpg/proxmox`, `hashicorp/vault`)
- Ansible (collections `community.general`, `community.proxmox`)
- Utilitaires : `sshpass`, `jq`, `passlib`

### Secrets

- HashiCorp Vault initialisé et déverrouillé
- Fichier `.env` local (kit d'amorçage) renseigné avec les accès Vault

---

## 5. Structure du dépôt

```
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
```

---

## 6. Ordre de déploiement (séquence d'amorçage PRA)

La reconstruction suit un ordre strict, car chaque étape dépend de la précédente. C'est le cœur de la logique PRA : on part d'un socle minimal pour reconstruire toute la chaîne.

### Étape 1 — pfSense (le réseau d'abord)

pfSense est déployé en premier. Sans lui, aucune segmentation ni routage inter-VLAN n'existe : les autres composants ne pourraient pas communiquer (par exemple Nextcloud en Vlan40 vers MariaDB en Vlan50). Il établit les passerelles, le filtrage et le VPN sortant.

### Étape 2 — HashiCorp Vault (les secrets ensuite)

Une fois le réseau en place, Vault est déployé et déverrouillé. Il devient la **source unique des secrets** : mots de passe, tokens, clés de chiffrement, accès NAS, etc. À ce stade, Vault est amorcé à partir du fichier `.env` local (le « secret zéro ») qui contient uniquement de quoi contacter et déverrouiller Vault.

### Étape 3 — Les autres services (secrets récupérés depuis Vault)

Le réseau et le coffre-fort étant opérationnels, tous les autres composants (Nagios, Graylog, MariaDB, Nextcloud) peuvent être déployés dans n'importe quel ordre. Leurs scripts d'orchestration ne contiennent **aucun secret en dur** : ils s'authentifient auprès de Vault (AppRole) et récupèrent dynamiquement les identifiants dont ils ont besoin au moment du déploiement.

```
pfSense  ──►  Vault  ──►  Nagios / Graylog / MariaDB / Nextcloud
(réseau)     (secrets)    (récupèrent leurs secrets depuis Vault)
```

### Exemple d'exécution

```bash
# Kit d'amorçage (accès Vault uniquement, non versionné)
cp .env.example .env   # puis renseigner les accès Vault

# 1. Réseau
./deploy-pfsense.sh

# 2. Coffre-fort de secrets (à déverrouiller après démarrage)
./deploy-vault.sh

# 3. Services applicatifs (secrets tirés de Vault)
./deploy-graylog.sh
./deploy-nextcloud.sh   # crée MariaDB + Nextcloud, puis restaure les données
```

Chaque script d'orchestration enchaîne : authentification Vault → récupération des secrets → provisioning Terraform → configuration Ansible → (le cas échéant) restauration des données depuis le NAS.

## 7. Sécurité des secrets

- **Aucun secret dans le dépôt** — exclusion stricte via `.gitignore` (`.env`, `*.snap`, `*.sql.gz`, backups, états Terraform).
- Secrets centralisés dans **HashiCorp Vault** et récupérés au moment du déploiement.
- Authentification des déploiements via **AppRole** (identifiants à durée de vie limitée).
- Le fichier `.env` (accès Vault) reste strictement local et n'est jamais versionné.

