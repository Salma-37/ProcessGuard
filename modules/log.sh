#!/bin/bash

LOG_DIR="./log"
LOG_FILE="$LOG_DIR/history.log"
ARCHIVE_DIR="$LOG_DIR/archives"
MAX_DAYS=7


_get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

_get_user() {
    whoami
}

_ecrire_log() {
    local type="$1"
    local message="$2"

    local horodatage
    local utilisateur

    horodatage="$(_get_timestamp)"
    utilisateur="$(_get_user)"

    local ligne="${horodatage} : ${utilisateur} : ${type} : ${message}"

    echo "$ligne" >> "$LOG_FILE"
}

init_log() {

    if [ ! -d "$LOG_DIR" ]; then

        mkdir -p "$LOG_DIR" 2>/dev/null

        if [ $? -ne 0 ]; then
            echo "ERROR: Impossible de créer le dossier : $LOG_DIR" >&2
            echo "INFO: Utilisation du dossier local ./logs à la place" >&2
            LOG_DIR="./logs"
            LOG_FILE="$LOG_DIR/history.log"
            ARCHIVE_DIR="$LOG_DIR/archives"
            mkdir -p "$LOG_DIR" "$ARCHIVE_DIR"
        fi
    fi

    if [ ! -d "$ARCHIVE_DIR" ]; then

        mkdir -p "$ARCHIVE_DIR"

        if [ $? -ne 0 ]; then
            echo "ERROR: Impossible de créer le dossier : $ARCHIVE_DIR" >&2
            exit 1
        fi
    fi

    if [ ! -f "$LOG_FILE" ]; then

        touch "$LOG_FILE" 2>/dev/null

        if [ $? -ne 0 ]; then
            echo "ERROR: Impossible de créer le fichier : $LOG_FILE" >&2
            exit 1
        fi
    fi

    # Redirection globale stdout et stderr vers tee (log + terminal)
    exec > >(tee -a "$LOG_FILE") 2>&1

    log_info "Système de logs initialisé → $LOG_FILE"
}

log_info() {

    local message="$1"

    if [ -z "$message" ]; then
        log_error "log_info appelée sans message"
        return 1
    fi

    _ecrire_log "INFOS" "$message"

    echo "[INFOS] $message"
}

log_warning() {

    local message="$1"

    if [ -z "$message" ]; then
        log_error "log_warning appelée sans message"
        return 1
    fi

    _ecrire_log "WARNING" "$message"

    echo "[WARNING] $message" >&2
}

log_error() {

    local message="$1"

    if [ -z "$message" ]; then

        _ecrire_log "ERROR" "log_error appelée sans message"

        echo "ERROR: log_error appelée sans message" >&2

        return 1
    fi

    _ecrire_log "ERROR" "$message"

    echo "[ERROR] $message" >&2
}

rotate_logs() {

    if [ ! -f "$LOG_FILE" ]; then
        log_error "[ERROR: rotate_logs : fichier de log introuvable"
        return 1
    fi

    local date_jour
    date_jour=$(date "+%Y-%m-%d")

    local fichier_archive="$ARCHIVE_DIR/processguard_$date_jour.log"

    mv "$LOG_FILE" "$fichier_archive"

    touch "$LOG_FILE"

    log_info "Rotation des logs effectuée"
}

archive_logs_by_date() {

    local date_cible

    date_cible="${1:-$(date -d "yesterday" "+%Y-%m-%d" 2>/dev/null || date -v-1d "+%Y-%m-%d")}"

    local dossier_date="$ARCHIVE_DIR/$date_cible"

    mkdir -p "$dossier_date"

    local fichiers_trouves=0

    for fichier in "$ARCHIVE_DIR"/processguard_"$date_cible"*.log; do

        if [ -f "$fichier" ]; then

            mv "$fichier" "$dossier_date/"

            fichiers_trouves=$((fichiers_trouves + 1))
        fi

    done

    if [ $fichiers_trouves -gt 0 ]; then

        log_info "$fichiers_trouves fichier(s) archivé(s)"

    else

        log_error "ERROR archive_logs_by_date : aucun fichier trouvé pour la date $date_cible"

    fi
} 

clear_old_logs() {

    local jours="${1:-$MAX_DAYS}"

    if [ ! -d "$ARCHIVE_DIR" ]; then
        log_error "ERROR: Dossier d'archives introuvable"
        return 1
    fi

    local nb_fichiers

    nb_fichiers=$(find "$ARCHIVE_DIR" -name "*.log" -mtime +"$jours" | wc -l)

    if [ "$nb_fichiers" -eq 0 ]; then

        log_info "Aucun ancien fichier à supprimer"

        return 0
    fi

    find "$ARCHIVE_DIR" -name "*.log" -mtime +"$jours" -delete

    log_info "$nb_fichiers ancien(s) fichier(s) supprimé(s)"
}

export_logs() {

    local destination="$1"
    local filtre="$2"

    if [ ! -f "$LOG_FILE" ]; then
        log_error "ERROR: Fichier source introuvable"
        return 1
    fi

    if [ -z "$destination" ]; then
        log_error "ERROR: Aucun fichier destination fourni"
        return 1
    fi

    if [ -z "$filtre" ]; then

        cp "$LOG_FILE" "$destination"

        log_info "Tous les logs exportés"

    else

        grep ": $filtre :" "$LOG_FILE" > "$destination"

        log_info "Logs de type $filtre exportés"

    fi
}
