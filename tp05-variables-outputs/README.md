# 🎛️ TP05 — Variables, outputs et types complexes

![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.12-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-S3-FF9900?logo=amazonwebservices&logoColor=white)
![Provider AWS](https://img.shields.io/badge/hashicorp%2Faws-~%3E%206.0-623CE4)
![Variables](https://img.shields.io/badge/Concept-Variables%20%26%20Outputs-0A66C2)
![Types](https://img.shields.io/badge/Types-list%20%7C%20map%20%7C%20object-2EA44F)
![Exam](https://img.shields.io/badge/Terraform%20Associate-004-844FBA)
![Status](https://img.shields.io/badge/Status-Completed-success)

> 👤 **Réalisé par Mouhamadou Moustapha THIAM** — Ingénieur DevOps / DevSecOps

---

## 📌 Objectif

Rendre une configuration Terraform **réutilisable** en remplaçant les valeurs écrites en dur :

- déclarer des **variables d'entrée** typées, avec ou sans valeur par défaut ;
- exposer des résultats avec des **outputs** ;
- comprendre l'**ordre de priorité** des sources de valeurs ;
- manipuler les **types complexes** : `list`, `map` et `object`.

| Bloc | Rôle | Analogie |
|------|------|----------|
| `variable` | **Entrée** : valeur fournie de l'extérieur | Paramètre d'une fonction |
| `output` | **Sortie** : valeur exposée après l'apply | Valeur de retour d'une fonction |

### Objectifs de l'examen couverts

| Code | Objectif |
|------|----------|
| 4c | Utiliser les variables et les outputs |
| 4d | Comprendre et utiliser les types complexes |
| 4b | Référencer des attributs de ressources |

---

## 📁 Structure du projet

```text
tp05-variables-outputs/
├── versions.tf               # Contraintes de version
├── variables.tf              # Déclaration des variables d'entrée
├── main.tf                   # Provider et bucket S3
├── outputs.tf                # Valeurs exposées
├── terraform.tfvars.example  # Exemple de valeurs (versionné)
├── .terraform.lock.hcl
└── README.md
```

`terraform.tfvars`, qui contient les vraies valeurs, est **exclu de Git** (`*.tfvars`).

---

## 🧩 Code

### `variables.tf`

```hcl
variable "environment" {
  description = "Environnement de deploiement"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Projet de deploiement S3"
  type        = string
  # Pas de défaut : valeur obligatoire
}

variable "balise" {
  description = "Balisages communs"
  type        = map(string)
  default = {
    Owner   = "mmt"
    Project = "Deploi-TF"
  }
}

variable "region_auto" {
  description = "Les regions autorisees"
  type        = list(string)
  default     = ["us-east-1", "eu-west-1"]
}

variable "compt_config" {
  description = "Configuration du compartiment"
  type = object({
    suffix        = string
    force_destroy = bool
  })
  default = {
    suffix        = "mmt"
    force_destroy = false
  }
}
```

### `main.tf`

```hcl
provider "aws" {
  region = var.region_auto[0]
}

resource "aws_s3_bucket" "stockage_s3" {
  bucket        = "${var.environment}-${var.project}-${var.compt_config.suffix}"
  force_destroy = var.compt_config.force_destroy
  tags          = var.balise
}
```

### `outputs.tf`

```hcl
output "aws_s3_bucket" {
  description = "Nom du compartiment S3"
  value       = aws_s3_bucket.stockage_s3.bucket
}

output "aws_s3_bucket_arn" {
  description = "ARN du compartiment S3"
  value       = aws_s3_bucket.stockage_s3.arn
}

output "premiere_region" {
  description = "Premiere region autorisee"
  value       = var.region_auto[0]
}
```

### `terraform.tfvars.example`

```hcl
project = "mon-projet"
```

---

## 🔬 Déroulé et observations

### 1. Variable obligatoire

Sans valeur par défaut, `project` est **obligatoire** : Terraform la demande de façon interactive.

```text
var.project
  Projet de deploiement S3

  Enter a value:
```

En CI/CD (`-input=false`), personne ne peut répondre : le plan échoue avec `No value for required variable`.

### 2. Outputs

```text
Outputs:

aws_s3_bucket     = "dev-deploiment-s3-mmt"
aws_s3_bucket_arn = "arn:aws:s3:::dev-deploiment-s3-mmt"
```

Les outputs sont **stockés dans le state** et se réaffichent sans contacter AWS :

```bash
terraform output                       # tous les outputs
terraform output aws_s3_bucket         # un seul  → "dev-deploiment-s3-mmt"
terraform output -raw aws_s3_bucket    # sans guillemets, pour les scripts
terraform output -json                 # format JSON, pour d'autres outils
```

Exemple d'utilisation dans un script :

```powershell
aws s3 cp test.txt "s3://$(terraform output -raw aws_s3_bucket)/"
```

### 3. Ordre de priorité des valeurs 🏆

Test réalisé en empilant les sources pour la variable `environment` :

| Test | Source ajoutée | Valeur retenue |
|------|----------------|----------------|
| 0 | `default = "dev"` | `dev` |
| 1 | `terraform.tfvars` → `"tfvars"` | `tfvars` |
| 2 | `$env:TF_VAR_environment="envvar"` | **`tfvars`** 😮 |
| 3 | `test.auto.tfvars` → `"auto"` | `auto` |
| 4 | `-var="environment=cli"` | `cli` |

**Ordre officiel, de la plus faible à la plus forte :**

| Rang | Source |
|------|--------|
| 1 | `default` dans le bloc `variable` |
| 2 | Variable d'environnement `TF_VAR_<nom>` |
| 3 | `terraform.tfvars` / `terraform.tfvars.json` |
| 4 | `*.auto.tfvars`, lus par ordre alphabétique |
| 5 | `-var` et `-var-file` en ligne de commande (le dernier l'emporte) |

> **CLI > auto.tfvars > tfvars > env > défaut**

⚠️ Piège classique : la variable d'environnement est **plus faible** que les fichiers `.tfvars`.
ℹ️ Seuls `terraform.tfvars` et `*.auto.tfvars` sont chargés automatiquement ; un `prod.tfvars` se passe avec `-var-file="prod.tfvars"`.

### 4. Conversion automatique des types

| Type attendu | Valeur fournie | Résultat |
|--------------|----------------|----------|
| `string` | `123` | ✅ converti en `"123"` |
| `string` | `["dev"]` | ❌ erreur |
| `bool` | `"true"` | ✅ converti en `true` |
| `bool` | `"oui"` | ❌ erreur |

Terraform convertit tout ce qui l'est **sans ambiguïté**.

### 5. Types complexes

| Type | Contenu | Accès |
|------|---------|-------|
| `list(string)` | Suite **ordonnée**, valeurs du même type | `var.region_auto[0]` (index à partir de 0) |
| `map(string)` | Clés **libres**, valeurs du **même type** | `var.balise["Owner"]` |
| `object({...})` | Attributs **fixés**, types **différents** possibles | `var.compt_config.suffix` |

**Pourquoi un `object` pour `compt_config` ?** Il mélange une chaîne (`suffix`) et un booléen (`force_destroy`). Une `map(string)` convertirait `false` en texte `"false"` ; seul un objet décrit une structure hétérogène.

### 6. Lecture du plan : hiérarchie des symboles

Remplacement des tags par la map `balise` (le tag `Environment` disparaît) :

```text
~ resource "aws_s3_bucket" "stockage_s3" {
    ~ tags = {
        - "Environment" = "dev" -> null
        ...
```

`~` au niveau de la **ressource** (modification sur place), `-` au niveau de l'**élément** retiré.

### 7. Ce que fait vraiment `force_destroy`

| `force_destroy` | Bucket vide | Bucket non vide |
|-----------------|-------------|-----------------|
| `false` (défaut) | ✅ détruit | ❌ échec (`BucketNotEmpty`) |
| `true` | ✅ détruit | ✅ fichiers supprimés, puis le bucket |

`false` **protège les données**, mais **n'empêche pas** la destruction d'un bucket vide. Pour interdire toute destruction : `lifecycle { prevent_destroy = true }` (TP07).

---

## 📖 Ce que j'ai appris

- Une variable se référence avec **`var.<nom>`**, une ressource avec **`<TYPE>.<NOM>.<ATTRIBUT>`**, une data source avec **`data.<TYPE>.<NOM>.<ATTRIBUT>`**.
- **`type`** décrit la **forme** (le moule), **`default`** contient les **valeurs**.
- Une variable sans défaut est **obligatoire**.
- Les outputs sont dans le state : `terraform output` ne contacte pas le cloud.
- Convention : `var.objet.attribut` pour un objet, `var.map["clé"]` pour une map.
- Les noms locaux Terraform suivent le **snake_case**, mais les **valeurs** envoyées au cloud suivent **ses règles** (pas d'`_` dans un nom de bucket S3).
- On versionne un `terraform.tfvars.example` pour documenter les valeurs attendues, jamais le vrai `terraform.tfvars`.

---

## 🐛 Difficultés rencontrées et solutions

### Préfixe `var.` sur une ressource

**Problème :** `value = var.aws_s3_bucket.stockage_s3` dans `outputs.tf`.
**Cause :** `var.` désigne uniquement une **variable** ; Terraform cherchait une variable `aws_s3_bucket`.
**Solution :** `aws_s3_bucket.stockage_s3.bucket` et `aws_s3_bucket.stockage_s3.arn`, avec l'**attribut** à la fin.

### Nom de bucket invalide

**Problème :** `InvalidBucketName: The specified bucket is not valid` pour `dev-deploiment_s3-mmt`.
**Cause :** un nom de bucket S3 n'accepte que des minuscules, des chiffres, des `-` et des `.` : pas d'underscore.
**Solution :** `project = "deploiment-s3"`.
**Réflexion :** l'erreur n'apparaît qu'à l'**apply**. Un bloc `validation` permettrait de la détecter dès le plan (TP08).

### Valeurs écrites dans `type`

**Problème :** `type = list("us-east-1", "eu-west-3")` et `type = object({ name_suffix = "mmt" })`.
**Cause :** confusion entre la **forme** et les **valeurs**.
**Solution :** `type = list(string)` + `default = ["us-east-1", "eu-west-1"]`.

### Liste ou objet entier dans une chaîne

**Problème :** `region = var.region_auto` et `"${var.comp_config}"` soulignés en rouge.
**Causes :** une liste entière passée là où une seule chaîne est attendue ; un nom de variable mal orthographié (`comp_config` au lieu de `compt_config`) ; un objet entier inséré dans une chaîne.
**Solution :** `var.region_auto[0]` et `var.compt_config.suffix`.

### Idées reçues corrigées

- ❌ « La variable d'environnement passe avant `terraform.tfvars` » → ✅ c'est l'inverse.
- ❌ « Une `map` n'accepte pas les booléens » → ✅ `map(bool)` existe ; une map impose seulement **un type unique** pour toutes ses valeurs.
- ❌ « `force_destroy = false` empêche la destruction » → ✅ il empêche seulement de supprimer un bucket **non vide**.

---

## ✅ Résultat

- [x] Variables `string`, `list`, `map` et `object` déclarées et utilisées
- [x] Outputs exposés et relus avec `terraform output` (`-raw`, `-json`)
- [x] Ordre de priorité des valeurs testé en pratique
- [x] Conversions automatiques de types comprises
- [x] `terraform.tfvars` exclu de Git, `terraform.tfvars.example` versionné
- [x] Infrastructure détruite : coût AWS nul

---

## 📚 Ressources

- [Exam Content List — Terraform Associate 004](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004)
- [Input Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Variable Definition Precedence](https://developer.hashicorp.com/terraform/language/values/variables#variable-definition-precedence)
- [Output Values](https://developer.hashicorp.com/terraform/language/values/outputs)
- [Type Constraints](https://developer.hashicorp.com/terraform/language/expressions/type-constraints)
- [Règles de nommage des buckets S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html)

---

## 👤 Auteur

**Mouhamadou Moustapha THIAM**
Ingénieur DevOps / DevSecOps

[![GitHub](https://img.shields.io/badge/GitHub-mouhamoustaphathiam--cmd-181717?logo=github&logoColor=white)](https://github.com/mouhamoustaphathiam-cmd)

*Infrastructure as Code · Cloud AWS · CI/CD · Sécurité*

---
