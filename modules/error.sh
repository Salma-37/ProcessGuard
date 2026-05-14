#!/bin/bash

readonly E_MISSING_PARAM=110      
readonly E_INVALID_FORMAT=111     
readonly E_PERMISSION_DENIED=112  
readonly E_NOT_FOUND=113          
readonly E_OPERATION_FAILED=114   
readonly E_INVALID_OPTION=115     
readonly E_GENERAL=1              

handle_error() {

    local message="$1"
    local code_sortie="${2:-1}"

    _ecrire_log "ERROR" "$message"

    echo "ERREUR : $message. Arrêt du programme." >&2
    
    exit "$code_sortie"
}
