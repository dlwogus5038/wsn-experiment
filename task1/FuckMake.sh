#!/bin/sh

while true; do
    make $*
    if [ $? -eq 0 ]; then
        break;
    fi
done
