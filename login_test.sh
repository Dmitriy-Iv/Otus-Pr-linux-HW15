#!/bin/bash

grp_mem=$(id "$PAM_USER" | grep admin)

if [ -n "$grp_mem" ]; then
    exit 0
elif [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun"  ] || [ $(date +%a) = "Thu"  ]; then
    exit 1
else
    exit 0
fi