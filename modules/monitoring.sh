#!/bin/bash

cpu_limit=80
memory_limit=80

monitor_cpu_usage() {

    local cpu
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print 100-$8}')

    log_info "monitor_cpu_usage : CPU = ${cpu}%"
    echo "CPU Usage : $cpu %"
}

monitor_memory_usage() {

    local memory
    memory=$(free | grep Mem | awk '{print $3/$2 * 100.0}')

    log_info "monitor_memory_usage : MEM = ${memory}%"
}

monitor_disk_usage() {

    local disk
    disk=$(df -h / | awk 'NR==2 {print $5}')

    log_info "monitor_disk_usage : DISK = $disk"
}

alert_on_threshold() {

    local cpu
    local memory

    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print 100-$8}')
    memory=$(free | grep Mem | awk '{print $3/$2 * 100.0}')

    local cpu_int=${cpu%.*}
    local memory_int=${memory%.*}

    if [ "$cpu_int" -gt "$cpu_limit" ]; then
        log_warning "ALERTE : CPU élevé ! (${cpu_int}% > seuil ${cpu_limit}%)"
    fi

    if [ "$memory_int" -gt "$memory_limit" ]; then
        log_warning "ALERTE : Mémoire élevée ! (${memory_int}% > seuil ${memory_limit}%)"
    fi

    detect_heavy_processes "$cpu_limit" "$memory_limit"
}

monitor_system() {

    log_info "monitor_system : démarrage de la surveillance système"

    while true; do
        clear

        echo "         MONITORING SYSTEME       "

        monitor_cpu_usage
        echo ""

        monitor_memory_usage
        echo ""

        monitor_disk_usage
        echo ""

        alert_on_threshold
        echo ""

        echo "Nouvelle vérification dans 5 secondes..."

        sleep 5
    done
}

start_background_monitor() {

    log_info "start_background_monitor : lancement en arrière-plan"
    monitor_system &
    log_info "Monitoring démarré en arrière-plan : PID=$!"
}