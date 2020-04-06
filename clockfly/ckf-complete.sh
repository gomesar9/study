#/usr/bin/env bash

COMMANDS_FILE=/opt/ckf/commands.lst
CKF_DIR="$HOME/.ckf"
WORKSPACES="$CKF_DIR/workspaces"


_ckf_complete() {
    IFS=$'\n'
    if [ $COMP_CWORD -eq 1 ]; then
        # Complete action
        COMPREPLY=($(compgen -W "$(cat $COMMANDS_FILE)" "${COMP_WORDS[1]}"))
    elif [ $COMP_CWORD -eq 2 ]; then
        # Complete workspace
        if [ -f $WORKSPACES ]; then
            local workspaces=($(compgen -W "$(cat $WORKSPACES | sed 's/^[^ ]* //')" "${COMP_WORDS[2]}"))

            if [ ${#workspaces[@]} -eq 1 ]; then
                local workspace_id="${workspaces[0]}"
                COMPREPLY=($workspace_id)
            else
                for i in "${!workspaces[@]}"; do
                    workspaces[$i]="$(printf '%*s' "-$COLUMNS"  "${workspaces[$i]}")"
                done

                COMPREPLY=("${workspaces[@]}")
            fi
        fi
    elif [ $COMP_CWORD -eq 3 ]; then
        # Complete project
        #echo "Using COMP_WORD[2]: \"${COMP_WORDS[2]}\", grep in \"$WORKSPACES\""
        local workspace_id="$(cat $WORKSPACES | grep "${COMP_WORDS[2]}" | cut -d' ' -f1)"
        local projects_f="$CKF_DIR/${workspace_id}.projects"
        #echo "Searching in \"$projects_f\""

        if [ -f $projects_f ]; then
            local projects=($(compgen -W "$(cat $projects_f | sed 's/^[^ ]* //')" "${COMP_WORDS[3]}"))
            if [ ${#projects[@]} -eq 1 ];then
                local project_id="\"${projects[0]}\""
                COMPREPLY=($project_id)
            else

                for i in "${!projects[@]}"; do
                    #projects[$i]="$(printf '%*q' "-$COLUMNS"  "${projects[$i]}")"
                    projects[$i]="$(printf '%q' "${projects[$i]}")"
                done

                COMPREPLY=("${projects[@]}")
            fi
        fi
    fi
}

complete -F _ckf_complete ckf
