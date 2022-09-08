#!/usr/bin/env bash
set -e

while getopts a:b: flag
do
    case "${flag}" in
        a) a=${OPTARG};;
        b) b=${OPTARG};;
    esac
done

if cmp -s $a $b; 
then
  echo -n "0x1124" # $, same
else 
  echo -n "0x1121" # !, different
fi
