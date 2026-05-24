#!/bin/sh
set -e

mkdir -p /paperclip/instances/default/logs
chown -R node:node /paperclip

gosu node node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js &
SERVER_PID=$!

until wget -qO /dev/null http://localhost:3100/api/health 2>/dev/null; do
  sleep 2
done

gosu node node -e "
const { createHash, randomBytes } = require('crypto');
const { Client } = require('pg');
(async () => {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  const { rows } = await client.query(\"SELECT COUNT(*) as c FROM instance_user_roles WHERE role = 'instance_admin'\");
  if (parseInt(rows[0].c) > 0) { await client.end(); return; }
  const token = 'pcp_bootstrap_' + randomBytes(24).toString('hex');
  const hash = createHash('sha256').update(token).digest('hex');
  const expires = new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString();
  await client.query(
    \"INSERT INTO invites (invite_type, token_hash, allowed_join_types, expires_at, invited_by_user_id) VALUES (\$1, \$2, \$3, \$4, \$5)\",
    ['bootstrap_ceo', hash, 'human', expires, 'system']
  );
  const base = process.env.PAPERCLIP_PUBLIC_URL || 'http://localhost:3100';
  console.log('========================================');
  console.log('PAPERCLIP ADMIN INVITE URL:');
  console.log(base + '/invite/' + token);
  console.log('Expires: ' + expires);
  console.log('========================================');
  await client.end();
})().catch(e => console.error('Bootstrap skipped:', e.message));
" 2>&1 || true

wait $SERVER_PID
