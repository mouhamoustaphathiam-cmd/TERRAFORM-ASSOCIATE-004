# TP13-14 — Drift, `moved`, `removed`, `import`, commandes `state` et logs

![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.12-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-S3-FF9900?logo=amazonwebservices&logoColor=white)
![Provider AWS](https://img.shields.io/badge/hashicorp%2Faws-~%3E%206.0-623CE4)
![Backend](https://img.shields.io/badge/Backend-S3-0A66C2)
![State](https://img.shields.io/badge/Concept-Drift%20%7C%20Import%20%7C%20State-2EA44F)
![Exam](https://img.shields.io/badge/Terraform%20Associate-004-844FBA)
![Status](https://img.shields.io/badge/Status-Completed-success)

> **Réalisé par Mouhamadou Moustapha THIAM** — Ingénieur DevOps / DevSecOps

---

## Objectif

Maintenir une infrastructure quand la réalité et Terraform ne sont plus d'accord :

| Étape | Situation réelle | Outil |
|---|---|---|
| 1 | Une ressource est modifiée à la main | `plan -refresh-only` / `apply -refresh-only` |
| 2 | Une ressource est renommée dans le code | bloc `moved` |
| 3 | Une ressource ne doit plus être gérée par Terraform | bloc `removed` |
| 4 | Une ressource existe déjà, créée hors de Terraform | bloc `import` |
| 5 | Il faut inspecter le state | `terraform state list`, `state show`, `show` |
| 6 | Terraform se comporte de façon inattendue | `TF_LOG`, `TF_LOG_PATH` |

### Objectifs de l'examen couverts

| Code | Objectif |
|------|----------|
| 6d | Gérer le drift et le state |
| 7a | Importer une infrastructure existante |
| 7b | Inspecter le state avec la CLI |
| 7c | Utiliser les logs détaillés |

---

## Structure du projet

```text
tp13-state/
├── versions.tf    # backend S3 (bucket du TP12, key tp13/terraform.tfstate)
├── main.tf
├── .terraform.lock.hcl
└── README.md
```

### `versions.tf`

```hcl
terraform {
  required_version = ">=1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }

  backend "s3" {
    bucket       = "mmt-tfstate-distant"
    key          = "tp13/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

---

## Étape 1 — Drift

**Point de départ :**

```hcl
resource "aws_s3_bucket" "drift" {
  bucket = "tp13-mmt-drift"
  tags = {
    Environment = "dev"
  }
}
```

Après l'apply, le tag est changé **à la main** dans la console AWS : `Environment = "prod"`.

| Commande | Résultat |
|---|---|
| `terraform plan` | `~ update in-place` : le tag repasse de `prod` à **`dev`**, car le **code** est la source de vérité |
| `terraform plan -refresh-only` | montre l'écart, **sans** proposer de modifier l'infrastructure |
| `terraform apply -refresh-only` | met à jour le **state** pour refléter la réalité (`prod`) |
| `terraform plan` après le refresh | veut **toujours** repasser à `dev` : le code n'a pas changé |

`-refresh-only` aligne le **state** sur la réalité, **jamais le code**.

| Décision face au drift | Action |
|---|---|
| La modification manuelle était une erreur | `terraform apply` : la valeur du code est rétablie |
| La modification manuelle est voulue | mettre à jour le **code**, puis vérifier `No changes` |
| Seulement constater l'écart | `terraform plan -refresh-only` |

L'ancienne commande `terraform refresh` est **dépréciée** : elle équivaut à `terraform apply -refresh-only -auto-approve`, sans relecture.

---

## Étape 2 — Renommer avec `moved`

```hcl
resource "aws_s3_bucket" "tp13-state" {   # ancien nom local : drift
  bucket = "tp13-mmt-drift"
}

moved {
  from = aws_s3_bucket.drift
  to   = aws_s3_bucket.tp13-state
}
```

```text
# aws_s3_bucket.drift has moved to aws_s3_bucket.tp13-state

Plan: 0 to add, 0 to change, 0 to destroy.
```

- Sans `moved`, le renommage provoque une **destruction** puis une **création** (constat du TP02).
- Avec `moved`, seule l'**adresse** change dans le state ; le bucket n'est pas touché dans AWS.
- Le bloc peut être retiré après l'apply, **sauf** si d'autres states utilisent le même code (autres environnements, module partagé) : il faut alors le conserver jusqu'à ce que tous aient appliqué.

| | Bloc `moved` | `terraform state mv` |
|---|---|---|
| Style | déclaratif, dans le code | impératif, en ligne de commande |
| Relecture | visible dans le plan et la pull request | appliqué immédiatement |

---

## Étape 3 — Ne plus gérer une ressource avec `removed`

Le bloc `resource` est supprimé et remplacé par :

```hcl
removed {
  from = aws_s3_bucket.tp13-state

  lifecycle {
    destroy = false
  }
}
```

- Le plan indique que Terraform **ne gérera plus** cet objet.
- Le bucket **existe toujours dans AWS**.
- Il **disparaît du state** (`terraform state list`).

Équivalent impératif : `terraform state rm aws_s3_bucket.tp13-state`.

---

## Étape 4 — Adopter une ressource existante avec `import`

Le bucket existe dans AWS mais n'est plus connu de Terraform : c'est la situation d'une ressource créée à la main.

```hcl
import {
  to = aws_s3_bucket.tp13-state
  id = "tp13-mmt-drift"
}

resource "aws_s3_bucket" "tp13-state" {
  bucket = "tp13-mmt-drift"
  tags = {
    Environment = "dev"
  }
}
```

```text
# aws_s3_bucket.tp13-state will be imported

Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
```

### Génération de la configuration

```bash
terraform plan -generate-config-out="genere.tf"
```

La fonctionnalité est **expérimentale**. Le fichier généré contenait tous les attributs du bucket et provoquait des erreurs :

| Erreur | Cause |
|---|---|
| `Value for unconfigurable attribute` | attributs **calculés** par AWS (`arn`, `bucket_domain_name`, `bucket_region`, `hosted_zone_id`…) |
| `Conflicting configuration arguments` | `bucket` et `bucket_prefix` présents en même temps |
| `Argument is deprecated` | `grant`, remplacé par `aws_s3_bucket_acl` |

Le fichier généré est un **point de départ à nettoyer**. Pour un bucket simple, écrire soi-même le bloc avec `bucket` et `tags` est plus rapide.

### Commande contre bloc

| | `terraform import <adresse> <id>` | Bloc `import` (Terraform 1.5+) |
|---|---|---|
| Aperçu | aucun : écrit directement dans le state | **plan** relu avant l'apply |
| Bloc `resource` | à écrire avant, à la main | peut être généré |
| Volume | une ressource par commande | plusieurs blocs en une opération |
| Trace | aucune dans le code | visible en pull request |
| CI/CD et HCP Terraform | difficile | adapté |

---

## Étape 5 — Inspecter le state

```bash
terraform state list
terraform state show aws_s3_bucket.tp13-state
terraform show
```

| Commande | Affiche |
|---|---|
| `terraform state list` | les adresses de toutes les ressources |
| `terraform state show <adresse>` | **une** ressource en détail |
| `terraform show` | **tout** le state (ressources et outputs), ou un fichier de plan |

| Commande | Effet | Équivalent déclaratif |
|---|---|---|
| `terraform state mv` | renomme une adresse | `moved` |
| `terraform state rm` | oublie une ressource sans la détruire | `removed` |
| `terraform import` | adopte une ressource existante | `import` |
| `terraform state pull` / `push` | télécharge ou envoie le state brut | — |

---

## Étape 6 — Logs détaillés

```powershell
$env:TF_LOG = "DEBUG"
terraform plan

$env:TF_LOG_PATH = "terraform.log"
terraform plan

Remove-Item Env:TF_LOG
Remove-Item Env:TF_LOG_PATH
```

| Niveau | Contenu |
|---|---|
| `TRACE` | tout, y compris chaque appel à l'API |
| `DEBUG` | fonctionnement interne |
| `INFO` | étapes principales |
| `WARN` | avertissements |
| `ERROR` | erreurs seulement |

- `TF_LOG_PATH` écrit les logs dans un fichier au lieu du terminal.
- `TF_LOG_CORE` et `TF_LOG_PROVIDER` séparent les logs du cœur de Terraform et ceux des providers.
- Les logs peuvent contenir des données sensibles : `*.log` est ajouté au `.gitignore`.

---

## Ce que j'ai appris

- Le **code** est la source de vérité : toute modification manuelle est annulée au prochain apply, sauf si on met le code à jour.
- `-refresh-only` met à jour le state, jamais le code ni l'infrastructure.
- Les méthodes **déclaratives** (`moved`, `removed`, `import`) passent par le plan et la revue de code ; les commandes **impératives** (`state mv`, `state rm`, `terraform import`) agissent immédiatement.
- `removed` avec `destroy = false` retire une ressource de Terraform sans la supprimer.
- La configuration générée à l'import doit toujours être relue et nettoyée.

---

## Difficultés rencontrées et solutions

### Configuration générée invalide

**Problème :** `terraform plan -generate-config-out="genere.tf"` échouait avec `Value for unconfigurable attribute` et `Conflicting configuration arguments`.
**Cause :** le fichier généré reprend tous les attributs, y compris ceux calculés par AWS et des arguments incompatibles.
**Solution :** supprimer `genere.tf` et écrire un bloc `resource` minimal (`bucket` et `tags`), puis lancer un `terraform plan` normal.

### `-refresh-only` ne règle pas le drift

**Constat :** après `apply -refresh-only`, le plan voulait toujours modifier le tag.
**Explication :** seul le state a été mis à jour ; le code contenait toujours l'ancienne valeur. Il faut choisir entre rétablir la valeur du code et mettre le code à jour.

---

## Résultat

- [x] Drift détecté et compris avec `-refresh-only`
- [x] Ressource renommée sans destruction avec `moved`
- [x] Ressource retirée de Terraform sans suppression avec `removed`
- [x] Ressource existante réimportée avec un bloc `import`
- [x] State inspecté avec les commandes `state` et `show`
- [x] Logs détaillés activés et redirigés vers un fichier
- [x] Infrastructure détruite : coût AWS nul

---

## Ressources

- [Exam Content List — Terraform Associate 004](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004)
- [Refresh-only Mode](https://developer.hashicorp.com/terraform/tutorials/state/refresh)
- [Refactoring with moved Blocks](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
- [The removed Block](https://developer.hashicorp.com/terraform/language/resources/syntax#removing-resources)
- [Import](https://developer.hashicorp.com/terraform/language/import)
- [Generating Configuration](https://developer.hashicorp.com/terraform/language/import/generating-configuration)
- [Command: state](https://developer.hashicorp.com/terraform/cli/commands/state)
- [Debugging Terraform](https://developer.hashicorp.com/terraform/internals/debugging)

---

## Auteur

**Mouhamadou Moustapha THIAM**
Ingénieur DevOps / DevSecOps

[![GitHub](https://img.shields.io/badge/GitHub-mouhamoustaphathiam--cmd-181717?logo=github&logoColor=white)](https://github.com/mouhamoustaphathiam-cmd)

*Infrastructure as Code · Cloud AWS · CI/CD · Sécurité*

---

Précédent : [TP12 — Backend S3](../tp12-backend/README.md) · [Sommaire](../README.md) · Suivant : TP15-16 — HCP Terraform
