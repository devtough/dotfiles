#!/usr/bin/env bash
# RAM usage script for macOS

# Get used memory (active + wired pages) in MiB
used_mem=$(vm_stat | grep ' active\|wired ' | sed 's/[^0-9]//g' | paste -sd ' ' - | awk -v pagesize=$(pagesize) '{printf "%d\n", ($1+$2) * pagesize / 1048576}')

# Get total memory in GB
total_mem=$(sysctl -n hw.memsize | awk '{printf "%.0f", $0/1024/1024/1024}')

# Format output
if (( used_mem < 1024 )); then
  echo "${used_mem}M/${total_mem}G"
else
  used_gb=$(( used_mem / 1024 ))
  echo "${used_gb}G/${total_mem}G"
fi
