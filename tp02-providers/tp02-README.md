# TP02 — Providers, contraintes de version et lock file

![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.12-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-S3-FF9900?logo=amazonwebservices&logoColor=white)
![Provider AWS](https://img.shields.io/badge/hashicorp%2Faws-~%3E%206.0-623CE4)
![Provider Random](https://img.shields.io/badge/hashicorp%2Frandom-~%3E%203.6.0-623CE4)
![Region](https://img.shields.io/badge/Region-us--east--1-232F3E)
![Exam](https://img.shields.io/badge/Terraform%20Associate-004-844FBA)
![Status](https://img.shields.io/badge/Status-Completed-success)

> **Réalisé par Mouhamadou Moustapha THIAM** — Ingénieur DevOps / DevSecOps

---

## Objectif

Comprendre **comment Terraform installe, versionne et utilise les providers** :

- déclarer **plusieurs providers** dans un même projet (`aws` + `random`) ;
- analyser ce que `terraform init` télécharge et où ;
- comprendre le rôle du fichier **`.terraform.lock.hcl`** ;
- provoquer puis résoudre un **conflit de versions** avec `terraform init -upgrade` ;
- faire **coopérer deux providers** : `random` génère un nom unique pour un bucket S3.

### Objectifs de l'examen couverts

| Code | Objectif |
|------|----------|
| 2a | Installer et versionner les providers Terraform |
| 2b | Décrire comment Terraform utilise les providers |
| 3b | Initialiser un répertoire de travail Terraform |
| 3d | Générer et analyser un plan d'exécution |
| 4b | Créer des références entre ressources |

---

## Ressources déployées

| Adresse Terraform | Provider | Rôle | Valeur obtenue |
|-------------------|----------|------|----------------|
| `random_pet.stockage` | `hashicorp/random` | Génère un nom aléatoire de 2 mots | `verified-marlin` |
| `aws_s3_bucket.tp02-` | `hashicorp/aws` | Bucket S3 nommé avec le pet | `tp02-verified-marlin` |

---

## Structure du projet

```text
tp02-providers/
├── versions.tf           # Contraintes de version de Terraform et des 2 providers
├── main.tf               # Provider AWS, random_pet et bucket S3
├── .terraform.lock.hcl   # Versions exactes + empreintes des providers (versionné)
└── README.md
```

---

## Code

### `versions.tf`

```hcl
terraform {
  required_version = ">=1.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6.0"
    }
  }
}
```

### `main.tf`

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "stockage" {
  length = 2
}

resource "aws_s3_bucket" "tp02-" {
  bucket = "tp02-${random_pet.stockage.id}"
}
```

---

## Déroulé et observations

### 1. Installation de deux providers

```bash
terraform init
```

Sans contrainte de version, Terraform a installé **la version la plus récente** de `random` (3.9.1).
**Attention :** Ce n'est vrai qu'en l'absence de lock file : s'il existe, `init` réinstalle toujours la version verrouillée.

### 2. Où sont stockés les providers ?

```text
.terraform/providers/registry.terraform.io/hashicorp/aws/6.x.x/windows_amd64/terraform-provider-aws_v6.x.x.exe
```

| Segment | Signification |
|---------|---------------|
| `registry.terraform.io` | Registre d'origine (hostname) |
| `hashicorp` | Namespace (éditeur) |
| `aws` | Type du provider |
| `6.x.x` | Version installée |
| `windows_amd64` | Système d'exploitation et architecture |

`source = "hashicorp/aws"` est la forme courte de `registry.terraform.io/hashicorp/aws`.
Un provider est un **binaire compilé par plateforme** : un poste Linux téléchargerait `linux_amd64`.

### 3. Anatomie du lock file

| Champ | Rôle |
|-------|------|
| `version` | Version **exacte** installée et verrouillée |
| `constraints` | Contrainte déclarée dans `versions.tf` (absente si aucune contrainte) |
| `hashes` | Empreintes de sécurité vérifiées à chaque `init` |

- `zh:` → empreinte de l'archive zip publiée sur le registre (une par plateforme) ;
- `h1:` → empreinte du contenu du paquet (schéma de hachage version 1).

Si un binaire téléchargé ne correspond pas aux empreintes, `init` échoue : protection contre un plugin corrompu ou malveillant.

### 4. Conflit de versions provoqué

Ajout de la contrainte `~> 3.6.0` sur `random` alors que le lock file contenait 3.9.1 :

| Fichier | Ce qu'il impose |
|---------|-----------------|
| `.terraform.lock.hcl` | version verrouillée **3.9.1** |
| `versions.tf` | uniquement **3.6.x** |

 `terraform init` **échoue** : il ne modifie jamais une version verrouillée de lui-même.

**Résolution :**

```bash
terraform init -upgrade
```

`-upgrade` ignore les versions verrouillées, choisit **la plus récente qui respecte les contraintes**, puis réécrit le lock file. Résultat : **3.6.3**. Ici, l'« upgrade » a même été un retour en arrière (3.9.1 → 3.6.3).

### 5. Faire coopérer deux providers

```bash
terraform plan
terraform apply
terraform state list
terraform providers
```

- Le nom du bucket est `(known after apply)` au moment du plan : il dépend du pet, généré seulement à l'apply. **Une valeur inconnue se propage** à tout ce qui l'utilise.
- Terraform sait quel provider gère quelle ressource grâce au **préfixe du type** : `aws_s3_bucket` → `aws`, `random_pet` → `random`.
- Ordre de création déduit automatiquement : `random_pet` puis `aws_s3_bucket`. C'est une **dépendance implicite**, issue de la référence `random_pet.stockage.id`.
- Le nom aléatoire **ne change pas** d'un plan à l'autre : il est enregistré dans le state.
- `terraform providers` affiche l'arbre des providers **requis** (par la configuration, les modules ou le state).

---

## Ce que j'ai appris

- `required_providers` = **quoi installer** ; bloc `provider` = **comment configurer**.
- `>= 1.2` n'est pas `>= 1.12` : les versions se comparent **nombre par nombre** (1.12 > 1.9).
- `~> 3.6.0` n'accepte que 3.6.x ; `~> 3.6` accepterait 3.7, 3.8, 3.9…
- Le lock file **doit être versionné** pour que toute l'équipe et la CI utilisent les mêmes binaires.
- `terraform init -upgrade` est la seule façon de faire évoluer une version verrouillée.
- Un remplacement `-/+` détruit **avant** de créer par défaut : coupure possible en production.
- Renommer le **nom local** d'une ressource n'est pas anodin : Terraform voit une ressource détruite et une nouvelle créée.

---

## Difficultés rencontrées et solutions

### Nom local ≠ nom du bucket AWS

**Problème :** le bucket s'est appelé `terraform-9207c60343e473ba444989ac43` au lieu de `tp02-<pet>`.

**Cause :** j'avais mis `tp02-` comme **nom local** de la ressource, mais laissé le bloc vide. Sans argument `bucket`, le provider AWS génère un nom automatiquement. Le `random_pet` existait, mais rien ne le reliait au bucket.

```hcl
# Avant
resource "aws_s3_bucket" "tp02-" {
}

# Après
resource "aws_s3_bucket" "tp02-" {
  bucket = "tp02-${random_pet.stockage.id}"
}
```

**Conséquence :** le nom d'un bucket étant immuable, le correctif a entraîné un **remplacement** (`1 to add, 0 to change, 1 to destroy`).

### Renommer une ressource dans le code

**Constat :** renommer `aws_s3_bucket.tp02-` en `aws_s3_bucket.stockage` produit **deux opérations distinctes** et non un `-/+` :

```text
# aws_s3_bucket.tp02- will be destroyed
# (because aws_s3_bucket.tp02- is not in configuration)
# aws_s3_bucket.stockage will be created
```

Terraform identifie une ressource **uniquement par son adresse**. La solution propre est le bloc `moved`, étudié au TP 13.

### Contrainte de version Terraform

**Problème :** `required_version = ">=1.2"` au lieu de `">=1.12"`, ce qui autorisait une version de 2022.

**Solution :** correction en `">=1.12"`, puisque les versions se comparent nombre par nombre.

---

## Résultat

- [x] Deux providers déclarés et installés
- [x] Structure de `.terraform/providers/` analysée
- [x] Lock file compris et versionné
- [x] Conflit de versions provoqué puis résolu avec `init -upgrade`
- [x] Bucket nommé dynamiquement : `tp02-verified-marlin`
- [x] Infrastructure détruite : coût AWS nul

---

## Ressources

- [Exam Content List — Terraform Associate 004](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004)
- [Provider Requirements](https://developer.hashicorp.com/terraform/language/providers/requirements)
- [Dependency Lock File](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
- [Ressource `random_pet` — Terraform Registry](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet)

---

## Auteur

**Mouhamadou Moustapha THIAM**
Ingénieur DevOps / DevSecOps

[![GitHub](https://img.shields.io/badge/GitHub-mouhamoustaphathiam--cmd-181717?logo=github&logoColor=white)](https://github.com/mouhamoustaphathiam-cmd)

*Infrastructure as Code · Cloud AWS · CI/CD · Sécurité*

---

Précédent : [TP01 — Workflow](../tp01-workflow/README.md) · [Sommaire](../README.md) · Suivant : TP03 — Plusieurs providers et alias
