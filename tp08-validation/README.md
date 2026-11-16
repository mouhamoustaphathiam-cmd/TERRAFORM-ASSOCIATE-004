# TP08 — Validation de la configuration avec des conditions personnalisées

![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.12-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-S3-FF9900?logo=amazonwebservices&logoColor=white)
![Provider AWS](https://img.shields.io/badge/hashicorp%2Faws-~%3E%206.0-623CE4)
![Validation](https://img.shields.io/badge/Concept-validation%20%7C%20conditions%20%7C%20check-0A66C2)
![Exam](https://img.shields.io/badge/Terraform%20Associate-004-844FBA)
![Status](https://img.shields.io/badge/Status-Completed-success)

> **Réalisé par Mouhamadou Moustapha THIAM** — Ingénieur DevOps / DevSecOps

---

## Objectif

Détecter les erreurs **le plus tôt possible** (*fail fast*) grâce aux trois niveaux de vérification de Terraform :

- refuser une **valeur d'entrée** invalide avec un bloc `validation` ;
- vérifier le **contexte** et le **résultat** d'une ressource avec `precondition` et `postcondition` ;
- **surveiller** l'infrastructure sans bloquer le déploiement avec un bloc `check`.

**Problème de départ (TP05) :** le nom `dev-deploiment_s3-mmt` n'avait été refusé par AWS qu'**à l'apply**, avec un message peu explicite (`InvalidBucketName`). L'objectif est de le refuser **dès le plan**, avec un message clair.

### Objectifs de l'examen couverts

| Code | Objectif |
|------|----------|
| 4g | Valider la configuration avec des conditions personnalisées |
| 4a | Utiliser les data sources |
| 4c | Utiliser les variables |

---

## Les trois mécanismes

| Mécanisme | Où | Vérifie | Si échec | Quand |
|---|---|---|---|---|
| `validation` | dans un bloc `variable` | une **valeur d'entrée** | **erreur** | au début du plan, sans contacter le cloud |
| `precondition` | dans `lifecycle` d'une ressource | le **contexte** avant création | **erreur** | au plan si possible |
| `postcondition` | dans `lifecycle` d'une ressource | le **résultat**, via `self` | **erreur** | après création, donc souvent à l'apply |
| `check` + `assert` | bloc **autonome** | l'**infrastructure** globale | **avertissement** seulement | fin du plan et de l'apply |

---

## Structure du projet

```text
tp08-validation/
├── versions.tf
├── variables.tf      # Variable nom_bucket et ses règles de validation
├── main.tf           # Data source, bucket avec pré/postconditions, bloc check
├── .terraform.lock.hcl
└── README.md
```

---

## Code

### `variables.tf`

```hcl
variable "nom_bucket" {
  description = "Nom du bucket S3"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.nom_bucket))
    error_message = "Le nom ne doit contenir que des minuscules, des chiffres et des tirets."
  }

  validation {
    condition     = length(var.nom_bucket) >= 3 && length(var.nom_bucket) <= 63
    error_message = "Le nom doit faire entre 3 et 63 caracteres."
  }
}
```

### `main.tf`

```hcl
provider "aws" {
  region = "us-east-1"
}

# Lit la région configurée dans le provider (aucun argument)
data "aws_region" "verif_region" {}

resource "aws_s3_bucket" "nom_bucket" {
  bucket = var.nom_bucket

  lifecycle {
    precondition {
      condition     = data.aws_region.verif_region.region == "us-east-1"
      error_message = "Verifiez la region du deploiement"
    }

    postcondition {
      condition     = self.bucket_region == data.aws_region.verif_region.region
      error_message = "Le bucket ne se trouve pas dans la region declaree"
    }
  }
}

check "conv_nommage" {
  assert {
    condition     = startswith(aws_s3_bucket.nom_bucket.bucket, "tp08-")
    error_message = "Verifier les conventions de nommage de l equipe"
  }
}
```

---

## Déroulé et observations

### 1. Validation d'une variable

```bash
terraform plan -var="nom_bucket=tp08-mmt-ok"   # passe
terraform plan -var="nom_bucket=Tp08_MMT"      # refusé
```

Le second plan échoue immédiatement avec le message personnalisé, **sans aucun appel à AWS**.

- `regex()` provoque une erreur si le motif ne correspond pas ; **`can()`** transforme cette erreur en `false` et un succès en `true`.
- Plusieurs règles : soit un seul bloc avec `&&` (un message unique), soit **plusieurs blocs `validation`** (un message précis par règle, préférable).
- **Nouveauté Terraform 1.9+ :** une condition de validation peut référencer **d'autres variables**.

### 2. `precondition` : vérifier le contexte

Provider passé en `eu-west-3` :

```text
Error: Resource precondition failed

Verifiez la region du deploiement
```

Terraform refuse de planifier le bucket hors de la région autorisée.

**Piège du provider AWS 6.x :** la data source `aws_region` accepte un argument `region` qui **force** la région interrogée. Avec `region = "us-east-1"` dans le bloc `data`, la précondition ne pourrait jamais échouer. Il faut laisser le bloc **vide** pour lire la région du provider.

### 3. `postcondition` : vérifier le résultat

- On ne peut pas référencer une ressource depuis elle-même : on utilise **`self`** (`self.bucket_region`).
- Au plan, `self.bucket_region` vaut `(known after apply)` : la vérification est **reportée après la création**.

### 4. Bloc `check` : surveiller sans bloquer

```bash
terraform apply -var="nom_bucket=mmt-test-check-2026"
```

```text
Warning: Check block assertion failed

Verifier les conventions de nommage de l equipe

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Le bucket est **créé malgré l'alerte**. Pour **imposer** le préfixe, il faudrait un bloc `validation` sur la variable.

---

## Ce que j'ai appris

- Une `condition` doit **produire** `true` ou `false` : on pose une question (`a == b`), on n'écrit pas `== true`.
- Une condition doit **référencer** un objet de la configuration, sinon elle ne vérifie rien.
- Pour une data source, toujours préciser l'**attribut** voulu : `data.aws_region.verif_region.region`, et non l'objet entier.
- `precondition` = **avant** (contexte) ; `postcondition` = **après** (résultat, avec `self`).
- Seul `check` est **non bloquant** : il sert à la surveillance.
- Valider au plan évite les erreurs tardives, les messages obscurs du fournisseur et les **applies partiels**.

---

## Difficultés rencontrées et solutions

### `postcondition` au lieu de `precondition`

**Problème :** la vérification de la région était placée dans une `postcondition`.
**Solution :** une vérification du contexte **avant** création est une `precondition`.

### Conditions qui ne posent pas de question

**Problème :** `condition = data.aws_region` puis `condition = data.aws_region.vrif_region == true`.
**Erreurs :** `There is no variable named "data"`, `The "data" object must be followed by two attribute names`.
**Cause :** référence incomplète, et comparaison d'un objet entier à `true`.
**Solution :** `data.aws_region.verif_region.region == "us-east-1"`.

### Indexation d'une chaîne

**Problème :** `self.bucket_region[data.aws_region]` (`Unsupported attribute`).
**Cause :** `bucket_region` est une simple chaîne, pas une liste ni une map.
**Solution :** une comparaison : `self.bucket_region == data.aws_region.verif_region.region`.

### Région inexistante

**Problème :** test avec `us-east-3`, qui n'existe pas (seules `us-east-1` et `us-east-2` existent ; Paris est `eu-west-3`).
**Conséquence :** l'erreur venait du provider, pas de la précondition.

### `check` sans référence

**Problème :** `condition = startswith("mmt", "_dev") == true`.
**Erreurs :** `Invalid assert expression` et `Zero assert blocks`.
**Cause :** la condition comparait deux textes fixes : elle ne vérifiait rien.
**Solution :** `startswith(aws_s3_bucket.nom_bucket.bucket, "tp08-")`.

### Nom de bucket refusé par AWS

**Constat :** un nom très court comme `mmt` est valide (3 à 63 caractères), mais il est presque toujours **déjà pris** par un autre compte AWS. Préférer des noms longs et personnels.

---

## Résultat

- [x] Nom de bucket invalide refusé dès le plan avec un message clair
- [x] Région non autorisée bloquée par une `precondition`
- [x] Résultat de la création vérifié par une `postcondition` avec `self`
- [x] Convention de nommage surveillée par un bloc `check` non bloquant
- [x] Infrastructure détruite : coût AWS nul

---

## Ressources

- [Exam Content List — Terraform Associate 004](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004)
- [Custom Conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions)
- [Input Variable Validation](https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules)
- [Checks](https://developer.hashicorp.com/terraform/language/checks)
- [Règles de nommage des buckets S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html)

---

## Auteur

**Mouhamadou Moustapha THIAM**
Ingénieur DevOps / DevSecOps

[![GitHub](https://img.shields.io/badge/GitHub-mouhamoustaphathiam--cmd-181717?logo=github&logoColor=white)](https://github.com/mouhamoustaphathiam-cmd)

*Infrastructure as Code · Cloud AWS · CI/CD · Sécurité*

---

Précédent : [TP07 — Lifecycle](../tp07-lifecycle/README.md) · [Sommaire](../README.md) · Suivant : TP09 — Données sensibles