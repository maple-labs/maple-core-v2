#!/usr/bin/env bash
set -e

while getopts f:i: flag
do
    case "${flag}" in
        f) file=${OPTARG};;
        i) input=${OPTARG};;
    esac
done

echo $input >> $file

echo "0x"
