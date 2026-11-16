# TP09 — Données sensibles : `sensitive`, valeurs éphémères et Vault

![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.12-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-SSM%20Parameter%20Store-FF9900?logo=amazonwebservices&logoColor=white)
![Provider AWS](https://img.shields.io/badge/hashicorp%2Faws-~%3E%206.0-623CE4)
![Security](https://img.shields.io/badge/Concept-Sensitive%20%7C%20Ephemeral%20%7C%20Write--only-C0392B)
![Exam](https://img.shields.io/badge/Terraform%20Associate-004-844FBA)
![Status](https://img.shields.io/badge/Status-Completed-success)

> **Réalisé par Mouhamadou Moustapha THIAM** — Ingénieur DevOps / DevSecOps

---

## Objectif

Gérer un **secret** (mot de passe de base de données) avec Terraform, en comprenant ce que chaque mécanisme protège réellement :

- masquer une valeur à l'affichage avec **`sensitive`** ;
- constater que le secret reste **en clair dans le state** ;
- empêcher tout enregistrement du secret grâce aux **valeurs éphémères** et aux **arguments write-only** ;
- connaître le rôle de **HashiCorp Vault**.

**Scénario :** le mot de passe d'une base de données est stocké, chiffré, dans **AWS SSM Parameter Store** (type `SecureString`, niveau standard gratuit).

### Objectifs de l'examen couverts

| Code | Objectif |
|------|----------|
| 4h | Bonnes pratiques de gestion des données sensibles, dont Vault |
| 4c | Variables et outputs |
| 2d | Comment Terraform utilise et gère le state |

---

## Structure du projet

```text
tp09-sensitive/
├── versions.tf
├── variables.tf      # Variable db_pwd, sensible puis éphémère
├── main.tf           # Paramètre SSM SecureString
├── .terraform.lock.hcl
└── README.md
```

---

## Code final

### `variables.tf`

```hcl
variable "db_pwd" {
  description = "Mot de passe de la base de donnees"
  type        = string
  sensitive   = true
  ephemeral   = true
}
```

### `main.tf`

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_ssm_parameter" "mdp_bd" {
  name             = "/tp09/bd_pwd"
  type             = "SecureString"
  value_wo         = var.db_pwd
  value_wo_version = 1
}
```

---

## Déroulé et observations

### Étape 1 — `sensitive = true` : masquer à l'affichage

Version initiale :

```hcl
variable "db_pwd" {
  type      = string
  sensitive = true
}

resource "aws_ssm_parameter" "mdp_bd" {
  name  = "/tp09/bd_pwd"
  type  = "SecureString"
  value = var.db_pwd
}

output "mot_de_passe" {
  value     = var.db_pwd
  sensitive = true
}
```

**Dans le plan :**

```text
+ value = (sensitive value)

Changes to Outputs:
  + mot_de_passe = (sensitive value)
```

- Terraform **propage** le caractère sensible : un output qui expose une valeur sensible doit lui aussi porter `sensitive = true`, sinon le plan échoue.
- `terraform output -raw mot_de_passe` affiche pourtant la valeur **en clair**, puisqu'on la demande explicitement.

**Dans `terraform.tfstate` :** le mot de passe apparaît **en clair**.

> `sensitive = true` **masque** la valeur à l'affichage, mais ne la **protège** pas : elle reste lisible dans le state.

### Étape 2 — Valeurs éphémères et argument write-only

Depuis Terraform **1.10** (valeurs éphémères) et **1.11** (arguments write-only), une valeur peut traverser Terraform **sans être enregistrée**.

```hcl
variable "db_pwd" {
  sensitive = true
  ephemeral = true
}

resource "aws_ssm_parameter" "mdp_bd" {
  value_wo         = var.db_pwd   # argument en écriture seule (suffixe _wo)
  value_wo_version = 1            # à incrémenter pour pousser un nouveau secret
}
```

- Une valeur éphémère est **refusée** dans un argument classique (`value`) : elle n'y serait pas oubliée.
- L'output `mot_de_passe` a été **supprimé** : un output de la configuration racine ne peut pas être éphémère.
- Terraform ne conserve pas la valeur, il ne peut donc pas détecter son changement : c'est **`value_wo_version`** qui signale qu'il faut réécrire le secret.

**Résultat :**

| | `value` + `sensitive` | `value_wo` + `ephemeral` |
|---|---|---|
| Visible dans le plan et l'apply | non | non |
| Enregistré dans le **state** | **oui, en clair** | **non** (`value_wo = null`) |
| Enregistré dans AWS Parameter Store | oui, chiffré | oui, chiffré |

Le secret traverse Terraform jusqu'au cloud **sans laisser de trace sur le disque**.

### Vault (notions)

- **HashiCorp Vault** est un coffre-fort à secrets : stockage, contrôle d'accès, et génération d'**identifiants dynamiques** à durée de vie limitée.
- Terraform y accède avec le **provider `vault`**.
- Une data source classique (`data "vault_kv_secret_v2"`) écrit le secret **dans le state** ; la **ressource éphémère** (`ephemeral "vault_kv_secret_v2"`) ne l'y écrit pas.
- Objectif : **aucun secret dans le code, ni dans les `.tfvars`, ni dans le state**.

---

## Ce que j'ai appris

| Mécanisme | Effet |
|---|---|
| `sensitive = true` | masque la valeur dans le plan, l'apply et les logs ; **reste en clair dans le state** |
| `ephemeral = true` (variable) | la valeur n'est enregistrée ni dans le plan, ni dans le state |
| Argument `*_wo` (write-only) | reçoit une valeur éphémère et l'envoie au fournisseur sans la stocker |
| `*_wo_version` | déclenche la réécriture d'un secret write-only |
| Ressource `ephemeral "type" "nom"` | lit ou génère un secret à la volée, sans l'enregistrer |
| `ephemeralasnull()` | remplace une valeur éphémère par `null` là où elle est interdite |

**Où une valeur éphémère est autorisée :** arguments write-only, configuration de provider, `locals`, autres valeurs éphémères, outputs de **modules enfants** (avec `ephemeral = true`). **Interdite :** arguments classiques et outputs de la racine.

**Bonnes pratiques :**
- traiter le **state comme une donnée sensible** : backend distant chiffré et accès restreint ;
- ne jamais committer le state ni les `.tfvars` contenant des secrets ;
- préférer les valeurs éphémères et un gestionnaire de secrets (Vault, AWS Secrets Manager) aux secrets en variables classiques ;
- ne jamais utiliser de vrai mot de passe dans un environnement de test.

---

## Difficultés rencontrées et solutions

### Valeur sans guillemets

**Problème :** `type = SecureString` → `Error: Invalid reference`.
**Cause :** sans guillemets, Terraform lit une **référence** vers un objet nommé `SecureString`.
**Solution :** `type = "SecureString"`. Règle : les valeurs fixes ont des guillemets, les références n'en ont pas.

### `ephemeralasnull()` dans un argument write-only

**Problème :** `value_wo = ephemeralasnull(var.db_pwd)`.
**Cause :** cette fonction remplace la valeur par `null` ; le paramètre aurait reçu un mot de passe vide.
**Solution :** `value_wo = var.db_pwd`, avec `value_wo_version = 1`. `ephemeralasnull()` sert uniquement là où une valeur éphémère est interdite.

---

## Résultat

- [x] Secret masqué à l'affichage avec `sensitive`
- [x] Secret retrouvé en clair dans le state : limite de `sensitive` démontrée
- [x] Secret transmis à AWS sans être enregistré dans le state (`ephemeral` + `value_wo`)
- [x] Rôle de Vault et des ressources éphémères compris
- [x] Infrastructure détruite : coût AWS nul

---

## Ressources

- [Exam Content List — Terraform Associate 004](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004)
- [Manage Sensitive Data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)
- [Ephemeral Values](https://developer.hashicorp.com/terraform/language/values/variables#exclude-values-from-state)
- [Write-only Arguments](https://developer.hashicorp.com/terraform/language/resources/ephemeral/write-only)
- [Vault Provider for Terraform](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)
- [Ressource `aws_ssm_parameter`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter)

---

## Auteur

**Mouhamadou Moustapha THIAM**
Ingénieur DevOps / DevSecOps

[![GitHub](https://img.shields.io/badge/GitHub-mouhamoustaphathiam--cmd-181717?logo=github&logoColor=white)](https://github.com/mouhamoustaphathiam-cmd)

*Infrastructure as Code · Cloud AWS · CI/CD · Sécurité*

---

Précédent : [TP08 — Validation](../tp08-validation/README.md) · [Sommaire](../README.md) · Suivant : TP10 — Modules