#!/bin/bash
# v1.0
# Ce script effectue des sauvegardes complètes et incrémentales de toutes les bases de données MySQL
# Il conserve les sauvegardes pendant X jours (BACKUP_EXPIRATION_DAYS)
# Ensuite, il purge automatiquement les sauvegardes expirées

# Chemin de destination des fichiers de sauvegarde
BACKUP_DIR="/chemin/vers/backups/"
FULL_BACKUP_DIR="${BACKUP_DIR}full/"
INCREMENTAL_BACKUP_DIR="${BACKUP_DIR}incremental/"

# Nom d'hôte ou adresse IP du serveur de base de données
BACKUP_HOST="VOTRE_HOTE"

# Nom d'utilisateur de la base de données
BACKUP_USER="VOTRE_UTILISATEUR"

# Options MySQL sécurisées
MYSQL_OPTS="--defaults-file=$(pwd)/.secret.cnf"

# Délai de conservation des sauvegardes en jours
BACKUP_EXPIRATION_DAYS=10

# Mode verbose : affiche des informations lors du dump
VERBOSE="Y"

# Active la compression GZIP ou non
GZIP_COMPRESSION="N"

# Ajoute l'option --add-drop-database lors du dump
ADD_DROP_DATABASE="N"

# Ajoute l'option --add-drop-table lors du dump
ADD_DROP_TABLE="Y"

# Nom du bucket S3
S3_BUCKET="s3://votre-bucket"
S3_FOLDER="backups"

# Heure du début du script
START_TIME=$(date +%s%N)

# On vérifie que l'utilisateur est en root ou en sudo
if [ -z "$SUDO_USER" ]; then
    echo "Vous devez exécuter ce script en root ou avec sudo"
    exit 13
fi 

### Check MySQL
PING=$(mysqladmin --defaults-file=$(pwd)/.secret.cnf ping 2>&1)
if [[ "$PING" != *"mysqld is alive"* ]]; then
    echo "Error: Unable to connect to MySQL Server, exiting !!"
    echo "$PING"
    exit 101
fi

# Vérifie si les dossiers de destination existent sinon les crée
[ ! -d "$FULL_BACKUP_DIR" ] && mkdir -p "$FULL_BACKUP_DIR"
[ ! -d "$INCREMENTAL_BACKUP_DIR" ] && mkdir -p "$INCREMENTAL_BACKUP_DIR"

# Récupération de la liste des bases de données
databases=$(mysql ${MYSQL_OPTS} --execute="SHOW DATABASES;" --batch | tail -n +2 | grep -Ev "^(information_schema|performance_schema|mysql|sys)$")

# Vérification si on a bien des bases de données
if [ -z "$databases" ]; then
    echo "Error: no databases found !!"
    exit 61
fi

# Détermine si c'est une sauvegarde complète ou incrémentale
DAY_OF_WEEK=$(date +%u)
if [ "$DAY_OF_WEEK" -eq 7 ]; then
    BACKUP_TYPE="full"
    BACKUP_DIR="$FULL_BACKUP_DIR"
else
    BACKUP_TYPE="incremental"
    BACKUP_DIR="$INCREMENTAL_BACKUP_DIR"
fi

# On parcourt la liste des bases de données
for database in $databases; do
    # Heure du début de dump de la database en cours
    START_DB_TIME=$(date +%s%N)
    if [ "$VERBOSE" = "Y" ]; then 
        echo "Traitement de la base $database en cours..."
    fi

    DATABASE_DIR="${BACKUP_DIR}${database}"
    [ ! -d "$DATABASE_DIR" ] && mkdir -p "$DATABASE_DIR"
    cd "$DATABASE_DIR" || exit

    # Début de la commande MySQL DUMP
    MYSQLDUMP_CMD="mysqldump ${MYSQL_OPTS} --single-transaction"
    
    # Ajout du DROP TABLE
    if [[ "$ADD_DROP_DATABASE" = "Y" || "$ADD_DROP_DATABASE" = "y" ]]; then
        MYSQLDUMP_CMD="${MYSQLDUMP_CMD} --add-drop-table"
    fi

    # Nom du fichier de sauvegarde avec date et heure
    TIMESTAMP=$(date +"%Y-%m-%d_%Hh%Mmin%S")
    BACKUP_FILE="${database}_${BACKUP_TYPE}_${TIMESTAMP}.sql"

    # Exécution de la commande mysqldump
    if [ "$BACKUP_TYPE" = "full" ]; then
        $MYSQLDUMP_CMD "$database" > "$BACKUP_FILE"
    else
        $MYSQLDUMP_CMD "$database" > "$BACKUP_FILE"
    fi

    # Compression GZIP si activée
    if [ "$GZIP_COMPRESSION" = "Y" ]; then
        gzip "$BACKUP_FILE"
        BACKUP_FILE="${BACKUP_FILE}.gz"
    fi

    # Upload vers S3
    S3_TARGET="$S3_BUCKET/$S3_FOLDER/$(basename "$BACKUP_FILE")"
    echo "Copying $BACKUP_FILE to $S3_TARGET"
    if ! aws s3 cp "$BACKUP_FILE" "$S3_TARGET"; then
        echo "Error: Failed to upload $BACKUP_FILE to S3"
        exit 102
    fi
done

# Purge des sauvegardes expirées
find "$FULL_BACKUP_DIR" -type f -mtime +$BACKUP_EXPIRATION_DAYS -exec rm {} \;
