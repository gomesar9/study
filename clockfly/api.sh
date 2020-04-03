#!/bin/bash
LOG_FILE='/var/log/ckf.log'
CKF_DIR='~/.ckf'
ENTRY_TIME_INFO_FILE="$CKF_DIR/.currentEntryTime.info"
CURRENT_ENTRY_TIME_FILE="$CKF_DIR/currentEntryTime"
API_KEY=''

function log_help() {
    echo "Usage: $0 <log_level_word> <text>"
}

function logger {
    if [ $# -ne 2 ]; then
        log_help
        return
    fi
    if [ $(echo "$1" | wc -w) -ne 1 ]; then
       echo "First arg must be a single word indicating log level."
        log_help
    fi
    log_level=${1^^}
    echo "$(date +'%Y-%m-%d %H:%M:%S') [$log_level] - $2" | tee -a $LOG_FILE
}

function query_api() {
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

function pretty_query_api() {
    query_api $1 $2 $3 | jq
}

function get_user_info() {
    query_api GET "user" | jq "$1"
}

function get_workspaces() {
    query_api GET "workspaces"
}

function get_projects() {
    workspaceId=$1
    query_api GET "workspaces/${workspaceId}/projects"
}

function refresh() {
    for workspaceId in $(get_workspaces | jq '.[].id' ); do
        get_projects $workspaceId | jq -r -c '.[]|.id + " " + .name' > "$CKF_DIR/$workspaceId.projects"
    done
}

function create_entrytime() {
    workspaceId=$1
    action=${2-start}
    nowTime=$(date --utc '+%Y-%m-%dT%H:%M:%S.000Z')

    if [ ! -d $CKF_DIR ];then
        mkdir -p $CKF_DIR
    fi

    set -o pipefail
    # If action is to create
    if [ "$action" = "start" ]; then
        projectId=$3
        query_api POST "/workspaces/${workspaceId}/time-entries" \
          "{\
            \"start\": \"$nowTime\",\
            \"description\": \"Teste de API\",\
            \"projectId\": \"$projectId\"\
          }" \
        | tee $ENTRY_TIME_INFO_FILE \
        && cat $ENTRY_TIME_INFO_FILE | jq -r '.id' > $CURRENT_ENTRY_TIME_FILE

    # Else if action is to close
    elif [ "$action" = "end" ]; then
        userId=$3
        if [ ! -f $CURRENT_ENTRY_TIME_FILE ]; then
            echo "$CURRENT_ENTRY_TIME_FILE not found."
            return 1
        else
            entryTimeId=$(cat $CURRENT_ENTRY_TIME_FILE)
        fi
        
        query_api PATCH "/workspaces/${workspaceId}/user/${userId}/time-entries" \
          "{\"end\": \"$nowTime\"}" \
        | tee -a $ENTRY_TIME_INFO_FILE

        if [ $(grep -c -o "\"end\":\"${nowTime:0:8}" $ENTRY_TIME_INFO_FILE) -ge 1 ]; then
            rm $CURRENT_ENTRY_TIME_FILE
            rm $ENTRY_TIME_INFO_FILE
        fi
    else
        echo "Invalid action. Please use 'start' or 'end'"
    fi
}

# Doc parts
#
# TimeEntryRequest: object
# {
#   "id": "string",
#   "start": "string",
#   "billable": "boolean",
#   "description": "string",
#   "projectId": "string",
#   "userId": "string",
#   "taskId": "string",
#   "end": "string",
#   "tagIds": [
#     "string"
#   ],
#   "timeInterval": {
#     "start": "string",
#     "end": "string"
#   },
#   "workspaceId": "string",
#   "isLocked": "boolean"
# }
