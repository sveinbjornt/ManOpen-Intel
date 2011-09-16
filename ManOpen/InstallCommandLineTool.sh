#!/bin/sh

# Create directories if they don't exist
mkdir -p /usr/local/bin

# Change to Resources directory of Platypus application, which is first argument
cd $1

# Copy resouces over
cp openman /usr/local/bin/openman

chmod -R 755 /usr/local/bin/openman
