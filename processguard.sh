#!/bin/bash

source ./modules/log.sh
source ./modules/error.sh
source ./modules/process.sh
source ./modules/monitoring.sh


LOG_DIR="./logs"
MODE="normal"
PARAMS=()
OPTION=""

parse_options() {

    if [[ $# -lt 1 ]]; then
        handle_error "Aucune option fournie. Utilisez --help" 101
    fi

    MODE="normal"
    OPTION=""
    PARAMS=()
    ACTION=""
    
    case "$1" in
        -f|-t|-s)
            MODE="$1"
            shift
            ;;
    esac

    OPTION="$1"

    if [[ -z "$OPTION" ]]; then
        handle_error "Aucune action fournie. Utilisez --help" 101
    fi

    if [[ "$OPTION" != -* ]]; then
        handle_error "Option invalide : '$OPTION'" 115
    fi

    shift

    PARAMS=("$@")

    ACTION="$OPTION"
}

check_permissions() {

    case "$OPTION" in
        -r|--restore|--archive-logs|--rotate-logs|--clear-logs)
            if [[ "$EUID" -ne 0 ]]; then
                handle_error "L'option '$OPTION' nécessite des privilèges administrateur (root)" 112
            fi
            ;;
    esac
}

show_help() {
cat << EOF

        ----- PROCESSGUARD DOCUMENTATION -----

NOM
    ProcessGuard - Outil de gestion des processus, monitoring et contrôle système

DESCRIPTION
    ProcessGuard est un outil en Bash permettant de :
    - gérer les processus système
    - surveiller l'activité du système
    - exécuter des actions avec différents modes (fork, thread, subshell)
    - gérer les logs et la configuration système

UTILISATION
    ./processguard.sh [option] [paramètres]


            * GESTION DES PROCESSUS *

--list [sort] [limit] [user]
    Affiche la liste des processus actifs
    sort : cpu | mem | pid
    limit : nombre max de résultats
    user  : filtrer par utilisateur

--search <type> <value>
    Recherche un processus spécifique
    type : name | pid | user

--kill <pid> [mode]
    Termine un processus
    mode : normal (défaut) | force

--stop <pid>
    Suspend un processus (SIGSTOP)

--resume <pid>
    Reprend un processus suspendu (SIGCONT)

--info <pid>
    Affiche les informations d'un processus

--detect-heavy [cpu_seuil] [mem_seuil] [limit]
    Détecte les processus consommant beaucoup de ressources
    Défaut : cpu=50, mem=50


            * MONITORING SYSTÈME *

--monitor
    Active la surveillance système en temps réel (boucle)

--background-monitor
    Lance la surveillance en arrière-plan

--monitor-local [interval] [duration]
    Surveille les processus locaux
    interval : secondes entre les mises à jour (défaut: 2)
    duration : nombre de cycles (défaut: 10)


            * GESTION DES LOGS *

--log-info <message>
    Ajoute un message d'information dans les logs

--log-warning <message>
    Ajoute un avertissement dans les logs

--log-error <message>
    Ajoute un message d'erreur dans les logs

--rotate-logs
    Effectue une rotation des logs (root requis)

--archive-logs [date]
    Archive les logs par date (root requis)

--clear-logs [jours]
    Supprime les anciens logs (root requis)

--export-logs <destination> [filtre]
    Exporte les logs vers un fichier


            * AUTRES OPTIONS *

-h, --help
    Affiche cette aide

-r, --restore
    Réinitialise la configuration par défaut (root requis)

-f <option> [params]
    Exécution via fork (processus fils)

-t <option> [params]
    Exécution via thread (arrière-plan)

-s <option> [params]
    Exécution dans un sous-shell isolé


            * CODES DES ERREURS *

110 : paramètre(s) manquant(s)
111 : format invalide
112 : permission requise
113 : command non trouvée
114 : opération échouée
115 : option invalide
1 : erreur générale


            * EXEMPLES *

./processguard.sh --list
./processguard.sh --list cpu 10
./processguard.sh --search name bash
./processguard.sh --kill 1234
./processguard.sh --kill 1234 force
./processguard.sh --detect-heavy 70 60
./processguard.sh --monitor
./processguard.sh --log-info "démarrage système"

EOF
}

handle_fork() {

    echo "Execution en mode fork..."

    (
        log_info "Processus fils cree avec PID : $$"
        dispatch_action
    )
}

handle_thread() {

    log_info "Execution en mode thread C..."

    ./bin/thread_manager "$OPTION" "${PARAMS[@]}"

    local status=$?

    if [[ $status -ne 0 ]]; then
        handle_error "Erreur thread manager" "$status"
    fi
}

handle_subshell() {

    log_info "Execution dans un sous-shell..."

    (
        dispatch_action
    )
}

execute_with_mode() {

    case "$OPTION" in
        -f)
            handle_fork
            ;;
        -t)
            handle_thread
            ;;
        -s)
            handle_subshell
            ;;
        *)
            dispatch_action
            ;;
    esac
}

restore_defaults() {

    log_info " RESTAURATION SYSTEME PROCESSGUARD "
    check_permissions
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p $LOG_DIR
        log_info "Dossier logs crée."
    fi

    if [[ ! -d "./config" ]]; then
        mkdir -p ./config
        echo "Dossier config créé."
    fi

    rm -f ./config/temp.conf
    cat > ./config/default.conf << EOF
            MODE=normal
            LOG_DIR=./logs
EOF

    MODE="normal"
    LOG_DIR="./logs"

    echo "Systeme restauré avec succès."
    echo "Mode : $MODE"
    echo "Logs : $LOG_DIR"
}

archive_logs() {

    echo "     ARCHIVAGE DES LOGS     "

    if [[ ! -d "$LOG_DIR" ]]; then
        handle_error "ERROR: dossier logs introuvable" 113
    fi

    ARCHIVE_NAME="logs_archive_$(date +%Y%m%d_%H%M%S).tar.gz"

    tar -czf "$ARCHIVE_NAME" "$LOG_DIR"

    if [[ $? -eq 0 ]]; then #? c'est le résultat de la dernière commande , 0 vaut le succès.
        log_info "Logs archivés avec succès : $ARCHIVE_NAME"
    else
        handle_error "Erreur lors de l'archivage des logs" 114
    fi
}

dispatch_action() {

    case "$OPTION" in

        # ---- Processus ----

        --list)
            list_processes "${PARAMS[0]}" "${PARAMS[1]}" "${PARAMS[2]}"
            ;;

        --search)
            if [[ ${#PARAMS[@]} -ne 2 ]]; then
                handle_error "Usage: --search <type> <value>  (type: name|pid|user)" 101
            fi
            search_process "${PARAMS[0]}" "${PARAMS[1]}"
            ;;

        --kill)
            if [[ ${#PARAMS[@]} -lt 1 ]]; then
                handle_error "Usage: --kill <pid> [mode]  (mode: normal|force)" 101
            fi
            kill_process "${PARAMS[0]}" "${PARAMS[1]}"
            ;;

        --stop)
            if [[ ${#PARAMS[@]} -ne 1 ]]; then
                handle_error "Usage: --stop <pid>" 101
            fi
            stop_process "${PARAMS[0]}"
            ;;

        --resume)
            if [[ ${#PARAMS[@]} -ne 1 ]]; then
                handle_error "Usage: --resume <pid>" 101
            fi
            resume_process "${PARAMS[0]}"
            ;;

        --info)
            if [[ ${#PARAMS[@]} -ne 1 ]]; then
                handle_error "Usage: --info <pid>" 101
            fi
            get_process_info "${PARAMS[0]}"
            ;;

        --detect-heavy)
            detect_heavy_processes "${PARAMS[0]}" "${PARAMS[1]}" "${PARAMS[2]}"
            ;;

        # ---- Monitoring ----

        --monitor)
            monitor_system
            ;;

        --background-monitor)
            start_background_monitor
            ;;

        --monitor-local)
            monitor_local_processes "${PARAMS[0]}" "${PARAMS[1]}"
            ;;

        # ---- Logs ----

        --log-info)
            if [[ ${#PARAMS[@]} -lt 1 ]]; then
                handle_error "Usage: --log-info <message>" 101
            fi
            log_info "${PARAMS[*]}"
            ;;

        --log-warning)
            if [[ ${#PARAMS[@]} -lt 1 ]]; then
                handle_error "Usage: --log-warning <message>" 101
            fi
            log_warning "${PARAMS[*]}"
            ;;

        --log-error)
            if [[ ${#PARAMS[@]} -lt 1 ]]; then
                handle_error "Usage: --log-error <message>" 101
            fi
            log_error "${PARAMS[*]}"
            ;;

        --rotate-logs)
            rotate_logs
            ;;

        --archive-logs)
            archive_logs_by_date "${PARAMS[0]}"
            ;;

        --clear-logs)
            clear_old_logs "${PARAMS[0]}"
            ;;

        --export-logs)
            if [[ ${#PARAMS[@]} -lt 1 ]]; then
                handle_error "Usage: --export-logs <destination> [filtre]" 101
            fi
            export_logs "${PARAMS[0]}" "${PARAMS[1]}"
            ;;

        # ---- Modes d'exécution ----

        -f)
            OPTION="${PARAMS[0]}"
            PARAMS=("${PARAMS[@]:1}")
            handle_fork
            ;;

        -t)
            OPTION="${PARAMS[0]}"
            PARAMS=("${PARAMS[@]:1}")
            handle_thread
            ;;

        -s)
            OPTION="${PARAMS[0]}"
            PARAMS=("${PARAMS[@]:1}")
            handle_subshell
            ;;

        # ---- Autres ----

        -h|--help)
            show_help
            ;;

        -r|--restore)
            restore_defaults
            ;;

        *)
            handle_error "Option inconnue : '$OPTION'. Utilisez --help pour l'aide." 115
            ;;
    esac
}

# Fonction principale 

main() {

    parse_options "$@"

    init_log

    log_info "ProcessGuard démarré — option: $OPTION | params: ${PARAMS[*]}"

    check_permissions

    dispatch_action
}

main "$@"
