#!/usr/bin/env bash
set -e

while getopts f: flag
do
    case "${flag}" in
        f) dir=${OPTARG};;
    esac
done

rm -rf $dir
mkdir -p $dir

echo "0x"
