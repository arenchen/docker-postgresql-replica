#!/usr/bin/env bash

echo "Waiting for primary is ready to accept connections"
while [ -z "$(docker exec -it -u postgres postgres pg_isready | grep 'accepting connections')" ]; do sleep 5; done
echo "Create user 'replicator'"
docker exec -it -u postgres postgres psql -c "CREATE ROLE replicator PASSWORD 'md515dae152476ec520534a02cef69eba78' NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN REPLICATION;"
echo "Add host-based authentication"
docker exec -it postgres bash -c "echo 'host    replication     replicator      0.0.0.0/0               trust' >> /var/lib/postgresql/data/pg_hba.conf"
echo "Trun on archive mode"
docker exec -it postgres bash -c "cat > /var/lib/postgresql/data/postgresql.auto.conf << EOF
archive_mode = on
archive_command = '/bin/date'
max_wal_senders = 10
synchronous_standby_names = '*'
EOF"
docker exec -it -u postgres postgres psql -tAc "SELECT case pg_reload_conf() when TRUE then 'Reload conf success' else 'Reload conf fail' end;"
echo "Backup base from primary"
docker exec -it -u postgres postgres-replica pg_basebackup -h postgres -p 5432 -D /var/lib/postgresql/repl -U replicator -Fp -Xs -P -R
echo "Stop replica"
docker-compose stop postgres-replica
echo "Restore replica"
docker cp postgres-replica:/var/lib/postgresql/repl/. ../vol/postgresql/postgres-replica/data/
echo "Start replica"
docker-compose start postgres-replica
echo "Remove temp"
docker exec -it -u postgres postgres-replica rm -rf /var/lib/postgresql/repl
