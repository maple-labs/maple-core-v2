#!/usr/bin/env bash
set -e

while getopts f: flag
do
    case "${flag}" in
        f) file=${OPTARG};;
    esac
done

rm -rf $file

echo "0x"
