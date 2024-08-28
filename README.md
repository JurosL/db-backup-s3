# Script de Sauvegarde MySQL

## Description
Ce script Bash automatisé effectue des sauvegardes complètes et incrémentales de toutes les bases de données MySQL. Il conserve les sauvegardes pendant un certain nombre de jours et purge automatiquement les sauvegardes expirées. Les sauvegardes peuvent être stockées localement et transférées vers un bucket S3 pour une conservation à long terme.

## Prérequis
- Serveur avec des privilèges root ou sudo
- MySQL installé et configuré
- AWS CLI configuré pour l'accès à S3

## Configuration
- **BACKUP_DIR** : Chemin de destination des fichiers de sauvegarde
- **BACKUP_HOST** : Nom d'hôte ou adresse IP du serveur de base de données
- **BACKUP_USER** : Nom d'utilisateur de la base de données
- **MYSQL_OPTS** : Options MySQL sécurisées
- **BACKUP_EXPIRATION_DAYS** : Délai de conservation des sauvegardes en jours
- **VERBOSE** : Mode verbose (Y/N)
- **GZIP_COMPRESSION** : Compression GZIP activée (Y/N)
- **ADD_DROP_DATABASE** : Ajout de l'option --add-drop-database (Y/N)
- **ADD_DROP_TABLE** : Ajout de l'option --add-drop-table (Y/N)
- **S3_BUCKET** : Nom du bucket S3
- **S3_FOLDER** : Dossier dans le bucket S3

## Création du fichier `.secret.cnf`
Pour sécuriser les identifiants de connexion MySQL, créez un fichier `.secret.cnf` dans le répertoire du script avec le contenu suivant :

```ini
[client]
user=VOTRE_UTILISATEUR
password=VOTRE_MOT_DE_PASSE
host=VOTRE_HOTE
