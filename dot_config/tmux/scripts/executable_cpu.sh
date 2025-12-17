#!/usr/bin/env bash
# CPU usage script for macOS

cpuvalue=$(ps -A -o %cpu | awk -F. '{s+=$1} END {print s}')
cpucores=$(sysctl -n hw.logicalcpu)
cpuusage=$(( cpuvalue / cpucores ))

echo "${cpuusage}%"
