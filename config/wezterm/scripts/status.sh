#!/bin/bash
# Prints "CPU x%  RAM y%  DISK z%  HH:MM  YYYY-MM-DD" for the WezTerm right status bar.
set -uo pipefail

cpu=$(top -l 1 -n 0 | awk '/CPU usage/ { gsub("%","",$3); gsub("%","",$5); printf "%.0f", $3+$5 }')

page_size=$(vm_stat | head -1 | sed -n 's/.*page size of \([0-9]*\) bytes.*/\1/p')

read -r active wired comp <<STATS
$(vm_stat | awk '
  /Pages active/ { a=$3 }
  /Pages wired down/ { w=$4 }
  /Pages occupied by compressor/ { c=$5 }
  END { gsub("\\.","",a); gsub("\\.","",w); gsub("\\.","",c); print a, w, c }
')
STATS

total_mem=$(sysctl -n hw.memsize)
ram=$(awk -v a="$active" -v w="$wired" -v c="$comp" -v ps="$page_size" -v t="$total_mem" \
  'BEGIN { used = (a+w+c) * ps; printf "%.0f", (used/t)*100 }')

disk=$(df -H / | awk 'NR==2 { gsub("%","",$5); print $5 }')

now=$(date "+%H:%M  %Y-%m-%d")

printf "CPU %s%%  RAM %s%%  DISK %s%%  %s" "$cpu" "$ram" "$disk" "$now"
