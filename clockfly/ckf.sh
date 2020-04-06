#!/bin/bash
LOG_FILE="/var/log/ckf.log"
CKF_DIR="$HOME/.ckf"
CURR_WORKSPACE_F="$CKF_DIR/current_workspace"
WORKSPACES_F="$CKF_DIR/workspaces"
USER_ID_F="$CKF_DIR/user_id"
ENTRY_TIME_INFO_FILE="$CKF_DIR/currentEntryTime.info"
CURRENT_ENTRY_TIME_FILE="$CKF_DIR/currentEntryTime"
API_KEY=''


function _log_help() {
    echo "Usage: $0 <log_level_word> <text>"
}

function _logger {
    if [ $# -ne 2 ]; then
        _log_help
        return
    fi
    if [ $(echo "$1" | wc -w) -ne 1 ]; then
       echo "First arg must be a single word indicating log level."
        _log_help
    fi
    log_level=${1^^}
    echo "$(date +'%Y-%m-%d %H:%M:%S') [$log_level] - $2" | tee -a $LOG_FILE
}

function _print_help() {
    echo "Usage:"
    echo "$0 <action> [<workspace> <project>]"
    echo "Example:"
    echo "    $0 refresh"
    echo "    $0 start myCompany projectOne"
    echo "    $0 end"
}

function _query_api() {
    local METHOD=$1
    local ENDPOINT=$2
    local BODY="$3"
    
    test -z "$BODY" \
        && curl -s -H "content-type: application/json" -H "X-Api-Key: ${API_KEY}" \
        -X $METHOD \
        https://api.clockify.me/api/v1/$ENDPOINT

    test -z "$BODY" || curl -s -H "content-type: application/json" -H "X-Api-Key: ${API_KEY}" \
        -X $METHOD \
        -d "$BODY" \
        https://api.clockify.me/api/v1/$ENDPOINT
}

function _pretty_query_api() {
    _query_api $1 $2 $3 | jq
}

function _get_user_info() {
    _query_api GET "user" | jq "$1"
}

function _get_workspaces() {
    _query_api GET "workspaces"
}

function _get_projects() {
    workspaceId=$1
    _query_api GET "workspaces/${workspaceId}/projects"
}

function _refresh() {
    rm -rf $CKF_DIR
    _logger INFO "CKF dir ($CKF_DIR) cleaned ($?)"
    mkdir -p $CKF_DIR
    _logger INFO "$CKF_DIR created"

    local userId="$(_get_user_info ".id" | sed 's/"//g')"
    echo "$userId" > $USER_ID_F
    _logger INFO "$USER_ID_F created. UserId: $userId"

    _get_workspaces | jq -r -c '.[]|.id + " " + .name' > $WORKSPACES_F
    _logger INFO "$WORKSPACES_F created"

    while IFS= read -r workspace; do
        workspaceId=${workspace%%\ *}
        _get_projects $workspaceId | jq -r -c '.[]|.id + " " + .name' > "$CKF_DIR/$workspaceId.projects"
        _logger INFO "${workspaceId}.project created"
    done < $WORKSPACES_F

    workspaces_count=$(wc -l $WORKSPACES_F | cut -d ' ' -f1)

    if [ $workspaces_count -eq 1 ];then
        _logger INFO "Only 1 workspace found. Making it current workspace."
        _get_workspaces | jq ".[].id" | sed 's/"//g' | head -n 1 > $CURR_WORKSPACE_F
        _logger INFO "$CURR_WORKSPACE_F created"
    elif [ $workspaces_count -gt 1 ]; then
        _logger INFO "$workspaces_count workspaces found"
    else
        _logger WARNING "No workspace found."
    fi
}

function _check_env() {

    if [ ! -d $CKF_DIR ]; then
        _logger ERRO "$CFK_DIR does not exist."
        echo "$CFK_DIR does not exist."
    fi
    if [ ! -f $WORKSPACES_F ]; then
        echo "$WORKSPACES_F does not exist."
    fi
    if [ ! -f $CURR_WORKSPACE_F ]; then
        echo "$CURR_WORKSPACE_F does not exist."
    fi
    if [ ! -f $CURRENT_ENTRY_TIME_FILE ]; then
        echo "$CURRENT_ENTRY_TIME_FILE does not exist."
    fi
    if [ ! -f $USER_ID_F ]; then
        echo "$USER_ID_F does not exist."
    fi
}

function _manage_entrytime() {
    action=${1-start}
    nowTime=$(date --utc '+%Y-%m-%dT%H:%M:%S.000Z')
    set -o pipefail

    # Checks
    local env_status="$(_check_env)"

    # If action is to create
    if [ "$action" = "start" ]; then
        if [ $(echo "$env_status" | grep -c "$WORKSPACES_F") -eq 1 ]; then
            _logger ERRO "$WORKSPACES_F does not exist. Impossible to start an EntryTime"
            return 1
        fi

        # Try to get workspaceId
        local workspaceId=$(cat $WORKSPACES_F | grep "$2" | cut -d' ' -f1)
        if [ ! -n "$workspaceId" ]; then
            _logger ERRO "workspaceId for workspace \"$2\" not found in \"$WORKSPACES_F\"."
            return 1
        fi
        _logger DEBUG "Workspace for name \"$2\" found in \"$WORKSPACES_F\": \"$workspaceId\"."

        # Try to get projectId
        local ws_projects_f="$CKF_DIR/${workspaceId}.projects"
        if [ ! -f "$ws_projects_f" ]; then
            _logger ERROR "Project list for workspace \"$workspaceId $2\" not found (\"$ws_projects_f\")."
            return 1
        fi
        _logger DEBUG "Projects folder found in \"$ws_projects_f\"."

        projectId=$(cat $ws_projects_f | grep "$3" | cut -d' ' -f1)
        if [ ! -n "$projectId" ]; then
            _logger ERRO "projectId for project \"$3\" not found in \"$ws_projects_f\"."
            return 1
        fi
        _logger DEBUG "projectId for project \"$3\" found in \"$ws_projects_f\": $projectId."

        _query_api POST "/workspaces/${workspaceId}/time-entries" \
          "{\
            \"start\": \"$nowTime\",\
            \"description\": \"Teste de API\",\
            \"projectId\": \"$projectId\"\
          }" \
        | tee $ENTRY_TIME_INFO_FILE \
        && cat $ENTRY_TIME_INFO_FILE | jq -r '.id' > $CURRENT_ENTRY_TIME_FILE

    # Else if action is to close
    elif [ "$action" = "end" ]; then
        workspaceId=$(head -n 1 $CURR_WORKSPACE_F)
        userId=$(head -n 1 $USER_ID_F)
        if [ ! -f $CURRENT_ENTRY_TIME_FILE ]; then
            _logger WARNING "$CURRENT_ENTRY_TIME_FILE not found."
            return 1
        else
            entryTimeId=$(cat $CURRENT_ENTRY_TIME_FILE)
        fi
        
        _query_api PATCH "/workspaces/${workspaceId}/user/${userId}/time-entries" \
          "{\"end\": \"$nowTime\"}" \
        | tee -a $ENTRY_TIME_INFO_FILE

        if [ $(grep -c -o "\"end\":\"${nowTime:0:8}" $ENTRY_TIME_INFO_FILE) -ge 1 ]; then
            rm $CURRENT_ENTRY_TIME_FILE
            rm $ENTRY_TIME_INFO_FILE
        fi
    else
        echo "Invalid action. Please use 'start' or 'end'"
    fi
    echo ""
}


# MAIN
if [ "$1" = "refresh" ];then
    _refresh
elif  [ "$1" = "end" ]; then
    _manage_entrytime "$1" "$2" "$3"
elif [ "$1" = "start" ] && [ $# -eq 3 ]; then
    _manage_entrytime "$1" "$2" "$3"
else
    echo "c é besta?"
    _print_help
fi

