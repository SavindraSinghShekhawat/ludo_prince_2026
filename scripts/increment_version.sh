#!/bin/bash

set -e

FILE="pubspec.yaml"

LINE=$(grep '^version:' $FILE)

VERSION=$(echo $LINE | cut -d '+' -f 1 | sed 's/version: //')
BUILD=$(echo $LINE | cut -d '+' -f 2)

NEW_BUILD=$((BUILD + 1))

sed -i.bak "s/$VERSION+$BUILD/$VERSION+$NEW_BUILD/" $FILE
rm $FILE.bak

echo "Version updated → $VERSION+$NEW_BUILD"