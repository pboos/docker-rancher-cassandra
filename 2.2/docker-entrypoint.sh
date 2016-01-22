#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1:0:1}" = '-' ]; then
	set -- cassandra -f "$@"
fi

if [ "$1" = 'cassandra' ]; then
	: ${CASSANDRA_RPC_ADDRESS='0.0.0.0'}

	if [ "$RANCHER_ENABLE" = 'true' ]; then
		RANCHER_META=http://rancher-metadata/2015-07-25
		PRIMARY_IP=$(curl --retry 3 --fail --silent $RANCHER_META/self/container/primary_ip)

		CASSANDRA_LISTEN_ADDRESS=$PRIMARY_IP
		CASSANDRA_BROADCAST_ADDRESS=$CASSANDRA_LISTEN_ADDRESS
		CASSANDRA_BROADCAST_RPC_ADDRESS=$CASSANDRA_BROADCAST_ADDRESS

		containers="$(curl --retry 3 --fail --silent $RANCHER_META/self/service/containers)"
		readarray -t containers_array <<<"$containers"
		#echo ${containers_array[0]}
		for i in "${containers_array[@]}"
		do
			container_name="$(curl --retry 3 --fail --silent $RANCHER_META/self/service/containers/$i)"
			container_ip="$(curl --retry 3 --fail --silent $RANCHER_META/containers/$container_name/primary_ip)"

			# TODO can we somehow check if container is already running correctly?

			if [ "$container_ip" != "$PRIMARY_IP" ]; then
				if [ -z "$CASSANDRA_SEEDS" ]; then
					CASSANDRA_SEEDS="$container_ip"
				else
					CASSANDRA_SEEDS="$CASSANDRA_SEEDS,$container_ip"
				fi
			fi
		done
	else
		: ${CASSANDRA_LISTEN_ADDRESS='auto'}
		if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
			CASSANDRA_LISTEN_ADDRESS="$(hostname --ip-address)"
		fi

		: ${CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"}

		if [ "$CASSANDRA_BROADCAST_ADDRESS" = 'auto' ]; then
			CASSANDRA_BROADCAST_ADDRESS="$(hostname --ip-address)"
		fi
		: ${CASSANDRA_BROADCAST_RPC_ADDRESS:=$CASSANDRA_BROADCAST_ADDRESS}

		if [ -n "${CASSANDRA_NAME:+1}" ]; then
			: ${CASSANDRA_SEEDS:="cassandra"}
		fi
	fi

	: ${CASSANDRA_SEEDS:="$CASSANDRA_BROADCAST_ADDRESS"}

	sed -ri 's/(- seeds:) "[0-9\.,]+"/\1 "'"$CASSANDRA_SEEDS"'"/' "$CASSANDRA_CONFIG/cassandra.yaml"

	for yaml in \
		broadcast_address \
		broadcast_rpc_address \
		cluster_name \
		endpoint_snitch \
		listen_address \
		num_tokens \
		rpc_address \
		start_rpc \
	; do
		var="CASSANDRA_${yaml^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -ri 's/^(# )?('"$yaml"':).*/\2 '"$val"'/' "$CASSANDRA_CONFIG/cassandra.yaml"
		fi
	done

	for rackdc in dc rack; do
		var="CASSANDRA_${rackdc^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -ri 's/^('"$rackdc"'=).*/\1 '"$val"'/' "$CASSANDRA_CONFIG/cassandra-rackdc.properties"
		fi
	done
fi

exec "$@"
