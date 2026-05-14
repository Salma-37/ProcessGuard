#!/bin/bash

validate_pid() {
    local pid=$1

    if [ -z "$pid" ]; then
        return 101
    fi

    if ps -p "$pid" > /dev/null 2>&1; then
        return 0   
    else
        return 1   
    fi
}

list_processes() {
    local sort=$1
    local limit=$2
    local user=$3

    local ps_output
    ps_output=$(ps -eo pid,user,%cpu,%mem,comm --no-headers)

    if [ -n "$user" ]; then
        ps_output=$(echo "$ps_output" | awk -v u="$user" '$2 == u')
    fi

    case "$sort" in
        cpu)
            ps_output=$(echo "$ps_output" | sort -k3 -rn)
            ;;
        mem)
            ps_output=$(echo "$ps_output" | sort -k4 -rn)
            ;;
        pid)
            ps_output=$(echo "$ps_output" | sort -k1 -n)
            ;;
    esac

    echo "PID   USER   CPU   MEM   COMMAND"

    if [ -n "$limit" ]; then
        echo "$ps_output" | head -n "$limit"
    else
        echo "$ps_output"
    fi
}


search_process() {
    local type=$1
    local value=$2

    if [ -z "$type" ] || [ -z "$value" ]; then
        log_error "ERROR: paramètres manquants (type=$type, value=$value)"
        return 101
    fi

    local result=""

    case "$type" in

        name)
            result=$(ps -eo pid,user,%cpu,%mem,comm --no-headers | grep -i "$value")
            ;;

        pid)
            result=$(ps -p "$value" -o pid,user,%cpu,%mem,comm --no-headers 2>/dev/null)
            ;;

        user)
            result=$(ps -u "$value" -o pid,user,%cpu,%mem,comm --no-headers 2>/dev/null)
            ;;

        *)
            log_error "ERROR: type de recherche invalide → $type"
            return 100
            ;;
    esac

    if [ "$type" == "name" ]; then
        result=$(echo "$result" | grep -v grep)
    fi

    if [ -z "$result" ]; then
        log_info "ERROR: aucun processus trouvé pour $type=$value"
        return 104
    fi

    echo "PID   USER   CPU   MEM   COMMAND"
    echo "$result"
}

detect_heavy_processes() {
    local cpu_threshold=${1:-50}
    local mem_threshold=${2:-50}
    local limit=$3

    if ! [[ "$cpu_threshold" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$mem_threshold" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "ERROR: seuils invalides (cpu=$cpu_threshold, mem=$mem_threshold)"
        return 101
    fi

    local result

    result=$(ps -eo pid,user,%cpu,%mem,comm --no-headers | \
        awk -v cpu="$cpu_threshold" -v mem="$mem_threshold" \
        '$3 > cpu || $4 > mem')

    if [ -z "$result" ]; then
        log_info "ERROR: aucun processus lourd détecté (cpu>${cpu_threshold}% ou mem>${mem_threshold}%)"
        return 104
    fi

    log_warning "detect_heavy_processes : processus lourds détectés"

    echo "PID   USER   CPU   MEM   COMMAND"

    if [ -n "$limit" ]; then
        echo "$result" | head -n "$limit"
    else
        echo "$result"
    fi
}

kill_process() {
    local pid=$1
    local mode=${2:-normal}

    if [ -z "$pid" ]; then
        handle_error "kill_process : PID manquant" 110
    fi

    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        handle_error "kill_process : format PID invalide → $pid" 111
    fi

    validate_pid "$pid"
    if [ $? -ne 0 ]; then
        handle_error "kill_process : processus introuvable → PID $pid" 113
    fi

    if [ "$pid" -eq 1 ]; then
        handle_error "kill_process : impossible de tuer le processus init" 114
    fi

    if [ "$mode" == "force" ]; then
        kill -9 "$pid" 2>/dev/null
    else
        kill -15 "$pid" 2>/dev/null
    fi

    sleep 1
    if ps -p "$pid" > /dev/null 2>&1; then
        log_error "ERROR kill_process : échec de la terminaison du processus $pid"
        return 105
    else
        log_info "kill_process : processus $pid terminé avec succès (mode=$mode)"
        return 0
    fi
}

stop_process() {
    local pid=$1

    if [ -z "$pid" ]; then
        handle_error "stop_process : PID manquant" 110
    fi

    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        handle_error "stop_process : format PID invalide → $pid" 111
    fi

    validate_pid "$pid"
    if [ $? -ne 0 ]; then
        handle_error "ERROR: processus introuvable → PID $pid" 113
    fi

    if [ "$pid" -eq 1 ]; then
        handle_error "ERROR: impossible d'arrêter le processus init" 114
    fi

    kill -STOP "$pid" 2>/dev/null

    if ps -o stat= -p "$pid" | grep -q "T"; then
        log_info "stop_process : processus $pid suspendu avec succès"
        echo "SUCCESS: process $pid stopped"
        return 0
    else
        log_error "ERROR stop_process : échec de la suspension du processus $pid"
        return 105
    fi
}

resume_process() {
    local pid=$1

    if [ -z "$pid" ]; then
        handle_error "resume_process : PID manquant" 110
    fi

    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        handle_error "resume_process : format PID invalide → $pid" 111
    fi

    validate_pid "$pid"
    if [ $? -ne 0 ]; then
        handle_error "resume_process : processus introuvable → PID $pid" 113
    fi

    if [ "$pid" -eq 1 ]; then
        handle_error "resume_process : impossible de reprendre le processus init" 114
    fi

    local status
    status=$(ps -o stat= -p "$pid")

    if ! echo "$status" | grep -q "T"; then
        log_error "ERROR resume_process : le processus $pid n'est pas suspendu"
        return 105
    fi

    kill -CONT "$pid" 2>/dev/null

    # Vérification
    sleep 1
    status=$(ps -o stat= -p "$pid")

    if echo "$status" | grep -q "T"; then
        log_error "ERROR resume_process : échec de la reprise du processus $pid"
        return 105
    else
        log_info "resume_process : processus $pid repris avec succès"
        echo "SUCCESS: process $pid resumed"
        return 0
    fi
}


get_process_info() {
    local pid=$1

    if [ -z "$pid" ]; then
        handle_error "get_process_info : PID manquant" 110
    fi

    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        handle_error "get_process_info : format PID invalide → $pid" 111
    fi

    validate_pid "$pid"
    if [ $? -ne 0 ]; then
        handle_error "get_process_info : processus introuvable → PID $pid" 113
    fi

    local result
    result=$(ps -p "$pid" -o pid=,user=,%cpu=,%mem=,comm=)

    if [ -z "$result" ]; then
        log_error "ERROR get_process_info : impossible de récupérer les infos du PID $pid"
        return 105
    fi

    echo "----- PROCESS INFO -----"
    echo "$result" | awk '{
        printf "PID: %s\nUSER: %s\nCPU: %s%%\nMEM: %s%%\nCOMMAND: %s\n",
        $1, $2, $3, $4, $5
    }'
}


monitor_local_processes() {
    local interval=${1:-2}
    local duration=${2:-10}

    if ! [[ "$interval" =~ ^[0-9]+$ ]] || ! [[ "$duration" =~ ^[0-9]+$ ]]; then
        log_error "ERROR monitor_local_processes : paramètres invalides (interval=$interval, duration=$duration)"
        return 101
    fi

    log_info "monitor_local_processes : démarrage (interval=${interval}s, duration=${duration}s)"

    local count=0

    while [ $count -lt $duration ]; do

        clear
        echo "----- PROCESS MONITOR -----"
        echo "Update: $((count+1)) / $duration"
        echo "Interval: ${interval}s"
        echo

        echo "PID   USER   CPU   MEM   COMMAND"
        ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n 11

        sleep "$interval"

        ((count++))
    done

    log_info "monitor_local_processes : surveillance terminée"
    echo "Monitoring finished."
}
