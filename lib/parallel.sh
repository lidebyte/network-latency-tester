# shellcheck shell=bash
# Bounded parallel helpers. Workers write records to temp files; parent renders UI.

get_concurrency_limit() {
    local value="${CONCURRENCY_LIMIT:-${LATENCY_CONCURRENCY:-6}}"
    if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ $value -lt 1 ]]; then
        value=6
    fi
    if [[ $value -gt 16 ]]; then
        value=16
    fi
    echo "$value"
}

parallel_run_records() {
    local worker="$1"
    local label="$2"
    shift 2
    local jobs=("$@")
    local total=${#jobs[@]}
    local limit
    limit=$(get_concurrency_limit)
    local pids=()
    local active=0
    local launched=0
    local completed=0
    PARALLEL_OUTPUT_FILES=()

    if [[ $total -eq 0 ]]; then
        return 0
    fi

    for item in "${jobs[@]}"; do
        local out log
        out=$(register_temp)
        log=$(register_temp)
        PARALLEL_OUTPUT_FILES+=("$out")
        "$worker" "$item" "$out" "$log" &
        pids+=("$!")
        ((++launched))
        ((++active))

        if [[ $active -ge $limit ]]; then
            local pid
            for pid in "${pids[@]}"; do
                wait "$pid" || true
                ((++completed))
                ui_progress "$label" "$completed" "$total"
            done
            pids=()
            active=0
        fi
    done

    local pid
    for pid in "${pids[@]}"; do
        wait "$pid" || true
        ((++completed))
        ui_progress "$label" "$completed" "$total"
    done
}
