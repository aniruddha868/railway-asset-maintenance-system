#!/usr/bin/env bash
# ==============================================================================
# Script Name : system-monitor.sh
# Description : System resource monitor and Railway Sensor IoT telemetry analyzer.
# Target OS   : Linux (Ubuntu/Debian, RHEL/CentOS, WSL, Git Bash)
# Author      : DevOps Engineering Team
# Usage       : ./scripts/system-monitor.sh [options]
# ==============================================================================

# Enable strict Bash execution mode:
# -e : Exit immediately if any command returns a non-zero exit code.
# -u : Treat unset variables as an error and exit immediately.
# -o pipefail : Causes a pipeline to return the exit status of the last command in
#               the pipe that returned a non-zero status.
set -euo pipefail

# ------------------------------------------------------------------------------
# Global Variables and Formatting Constants
# ------------------------------------------------------------------------------
# ANSI Color Codes for terminal visual feedback
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_GREEN="\033[32m"
CLR_YELLOW="\033[33m"
CLR_RED="\033[31m"
CLR_BLUE="\033[34m"
CLR_CYAN="\033[36m"

# Resolve script root directory to safely locate sibling folders (like sample-data)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_FILE="${PROJECT_ROOT}/sample-data/railway-sensor-data.csv"
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/system-monitor-$(date +'%Y%m%d').log"

# Default resource threshold percentages for alerting
CPU_ALERT_THRESHOLD=80
MEM_ALERT_THRESHOLD=80
DISK_ALERT_THRESHOLD=85

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

# Print section headers with clean styling
print_banner() {
    echo -e "${CLR_BLUE}${CLR_BOLD}==================================================================${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}   RAILWAY ASSET MAINTENANCE SYSTEM - HEALTH & TELEMETRY MONITOR  ${CLR_RESET}"
    echo -e "${CLR_BLUE}${CLR_BOLD}==================================================================${CLR_RESET}"
    echo -e " Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ') (UTC)"
    echo -e " Hostname : $(hostname 2>/dev/null || echo 'localhost')"
    echo -e " Base Dir : ${PROJECT_ROOT}"
    echo ""
}

# Display available options and usage help
show_help() {
    echo -e "${CLR_BOLD}Usage:${CLR_RESET} $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --all             Run full diagnostic (system resources + sensor telemetry)"
    echo "  --system          Check only system health (CPU, Memory, Disk)"
    echo "  --sensors         Analyze only railway sensor IoT data from CSV"
    echo "  --help            Display this help message and exit"
    echo ""
    echo "Example:"
    echo "  $0 --all"
}

# Ensure required log directory exists
init_environment() {
    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}"
    fi
}

# Log messages to both standard output and the persistent log file
log_info() {
    local msg="$1"
    echo -e "${CLR_GREEN}[INFO]${CLR_RESET} ${msg}"
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INFO] ${msg}" >> "${LOG_FILE}"
}

log_warn() {
    local msg="$1"
    echo -e "${CLR_YELLOW}[WARN]${CLR_RESET} ${msg}"
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WARN] ${msg}" >> "${LOG_FILE}"
}

log_crit() {
    local msg="$1"
    echo -e "${CLR_RED}[CRITICAL]${CLR_RESET} ${msg}"
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [CRITICAL] ${msg}" >> "${LOG_FILE}"
}

# ------------------------------------------------------------------------------
# System Resource Checks
# ------------------------------------------------------------------------------
check_system_resources() {
    echo -e "${CLR_BOLD}>>> 1. Checking Edge Host System Resources...${CLR_RESET}"

    # 1. CPU Load Average Check
    echo -n " - CPU Load (1m, 5m, 15m)       : "
    if [[ -r /proc/loadavg ]]; then
        local load_1m
        load_1m=$(awk '{print $1}' /proc/loadavg)
        local load_5m
        load_5m=$(awk '{print $2}' /proc/loadavg)
        local load_15m
        load_15m=$(awk '{print $3}' /proc/loadavg)
        echo "${load_1m}, ${load_5m}, ${load_15m}"
    elif command -v uptime >/dev/null 2>&1; then
        uptime | awk -F'load average:' '{ print $2 }'
    else
        echo "N/A (system metrics unavailable in this environment)"
    fi

    # 2. Memory Utilization Check
    echo -n " - Memory Utilization           : "
    if command -v free >/dev/null 2>&1; then
        local mem_total
        local mem_used
        local mem_percent
        mem_total=$(free -m | awk '/Mem:/ {print $2}')
        mem_used=$(free -m | awk '/Mem:/ {print $3}')
        if [[ "${mem_total}" -gt 0 ]]; then
            mem_percent=$((mem_used * 100 / mem_total))
            echo "${mem_used}MB / ${mem_total}MB (${mem_percent}%)"
            if [[ "${mem_percent}" -ge "${MEM_ALERT_THRESHOLD}" ]]; then
                log_warn "Memory usage is above threshold (${mem_percent}% >= ${MEM_ALERT_THRESHOLD}%)"
            fi
        else
            echo "Unable to calculate memory ratio"
        fi
    elif [[ -r /proc/meminfo ]]; then
        local mem_kb
        mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
        echo "$((mem_kb / 1024)) MB total"
    else
        echo "free command not found, skipping detailed memory statistics"
    fi

    # 3. Disk Space Utilization Check
    echo -n " - Primary Disk Partition Usage : "
    if command -v df >/dev/null 2>&1; then
        # Check primary mount point or workspace root disk
        local disk_info
        disk_info=$(df -h "${PROJECT_ROOT}" | awk 'NR==2 {print $5 " used (" $3 "/" $2 " on " $6 ")"}')
        echo "${disk_info}"

        local disk_pct
        disk_pct=$(df -P "${PROJECT_ROOT}" | awk 'NR==2 {gsub("%",""); print $5}')
        if [[ "${disk_pct}" =~ ^[0-9]+$ ]] && [[ "${disk_pct}" -ge "${DISK_ALERT_THRESHOLD}" ]]; then
            log_warn "Disk space usage is high: ${disk_pct}% (Threshold: ${DISK_ALERT_THRESHOLD}%)"
        fi
    else
        echo "df command not available"
    fi

    echo ""
}

# ------------------------------------------------------------------------------
# Railway Telemetry CSV Analyzer
# ------------------------------------------------------------------------------
analyze_sensor_data() {
    echo -e "${CLR_BOLD}>>> 2. Analyzing Railway IoT Sensor Telemetry...${CLR_RESET}"

    if [[ ! -f "${DATA_FILE}" ]]; then
        log_crit "Sensor data file not found at: ${DATA_FILE}"
        return 1
    fi

    local total_records=0
    local normal_count=0
    local warning_count=0
    local critical_count=0

    # Read CSV skipping header row
    # Expected columns: timestamp,asset_id,asset_type,location_km,temperature_celsius,vibration_rms_mm_s,pressure_bar,status,maintenance_recommended
    while IFS=',' read -r timestamp asset_id asset_type location_km temp vib press status maint || [[ -n "${timestamp}" ]]; do
        # Skip header
        if [[ "${timestamp}" == "timestamp" ]] || [[ -z "${timestamp}" ]]; then
            continue
        fi

        total_records=$((total_records + 1))

        case "${status}" in
            "Normal")
                normal_count=$((normal_count + 1))
                ;;
            "Warning")
                warning_count=$((warning_count + 1))
                ;;
            "Critical")
                critical_count=$((critical_count + 1))
                ;;
            *)
                ;;
        esac
    done < "${DATA_FILE}"

    echo -e " Data Source        : ${CLR_CYAN}${DATA_FILE}${CLR_RESET}"
    echo -e " Total Assets Monitored : ${CLR_BOLD}${total_records}${CLR_RESET}"
    echo -e " [STATUS] Normal    : ${CLR_GREEN}${normal_count}${CLR_RESET}"
    echo -e " [STATUS] Warning   : ${CLR_YELLOW}${warning_count}${CLR_RESET}"
    echo -e " [STATUS] Critical  : ${CLR_RED}${critical_count}${CLR_RESET}"
    echo ""

    # Highlight any assets currently in Warning or Critical condition
    echo -e "${CLR_BOLD}Action Items / Maintenance Required:${CLR_RESET}"
    echo "----------------------------------------------------------------------------------------------------"
    printf "%-18s %-20s %-12s %-10s %-10s %-10s\n" "Asset ID" "Type" "Location" "Temp(°C)" "Vibration" "Status"
    echo "----------------------------------------------------------------------------------------------------"

    while IFS=',' read -r timestamp asset_id asset_type location_km temp vib press status maint || [[ -n "${timestamp}" ]]; do
        if [[ "${status}" == "Critical" ]]; then
            printf "${CLR_RED}%-18s %-20s %-12s %-10s %-10s %-10s${CLR_RESET}\n" \
                "${asset_id}" "${asset_type}" "${location_km}km" "${temp}°C" "${vib}" "${status}"
            log_crit "Asset ${asset_id} (${asset_type}) at ${location_km}km in CRITICAL state! Temp=${temp}°C, Vib=${vib}"
        elif [[ "${status}" == "Warning" ]]; then
            printf "${CLR_YELLOW}%-18s %-20s %-12s %-10s %-10s %-10s${CLR_RESET}\n" \
                "${asset_id}" "${asset_type}" "${location_km}km" "${temp}°C" "${vib}" "${status}"
            log_warn "Asset ${asset_id} (${asset_type}) at ${location_km}km needs scheduled inspection. Temp=${temp}°C, Vib=${vib}"
        fi
    done < "${DATA_FILE}"
    echo "----------------------------------------------------------------------------------------------------"
    echo ""
}

# ------------------------------------------------------------------------------
# Main Entrypoint
# ------------------------------------------------------------------------------
main() {
    init_environment
    print_banner

    local mode="${1:---all}"

    case "${mode}" in
        --all)
            check_system_resources
            analyze_sensor_data
            log_info "Full diagnostic scan completed successfully."
            ;;
        --system)
            check_system_resources
            log_info "System resource inspection completed."
            ;;
        --sensors)
            analyze_sensor_data
            log_info "Sensor telemetry analysis completed."
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${CLR_RED}Unknown option: ${mode}${CLR_RESET}"
            show_help
            exit 1
            ;;
    esac

    echo -e "${CLR_GREEN}Log saved to:${CLR_RESET} ${LOG_FILE}"
}

# Execute main function with passed script arguments
main "$@"
