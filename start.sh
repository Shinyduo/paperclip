#!/bin/sh
set -e

mkdir -p /paperclip/instances/default/logs
chown -R node:node /paperclip

exec gosu node node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
