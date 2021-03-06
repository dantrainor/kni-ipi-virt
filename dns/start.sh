#!/bin/bash

# shellcheck disable=SC1091
source "common.sh"

"$PROJECT_DIR"/dns/stop.sh

OUTPUT_DIR="$PROJECT_DIR/dns/generated"

CONTAINER_NAME="ipi-coredns"

export API_OCTET=$(echo "$API_VIP" | cut -d '.' -f 4)
export BM_GW_OCTET=$(echo "$BM_GW_IP" | cut -d '.' -f 4)
export DNS_OCTET=$(echo "$DNS_VIP" | cut -d '.' -f 4)

mkdir -p "$OUTPUT_DIR"

envsubst < "$PROJECT_DIR/dns/Corefile.tmpl" > "${OUTPUT_DIR}"/Corefile
# shellcheck disable=SC2016
#envsubst '${CLUSTER_DOMAIN} ${CLUSTER_NAME} ${API_VIP} ${DNS_VIP} ${INGRESS_VIP}' < db.zone.tmpl > "${OUTPUT_DIR}"/db.zone
# shellcheck disable=SC2016
#envsubst '${CLUSTER_DOMAIN} ${CLUSTER_NAME} ${API_OCTET} ${DNS_OCTET}' < db.reverse.tmpl > "${OUTPUT_DIR}"/db.reverse

DB_ZONE_CONF="$(envsubst '${CLUSTER_DOMAIN} ${CLUSTER_NAME} ${API_VIP} ${DNS_VIP} ${INGRESS_VIP} ${BM_GW_IP}' < "$PROJECT_DIR/dns/db.zone.tmpl")"

for i in $(seq 0 $((NUM_MASTERS - 1))); do
    DB_ZONE_CONF="$DB_ZONE_CONF\n$CLUSTER_NAME-master-$i                          A 10.0.1.12$i"
done

for i in $(seq 0 $((NUM_WORKERS - 1))); do
    DB_ZONE_CONF="$DB_ZONE_CONF\n$CLUSTER_NAME-worker-$i                          A 10.0.1.13$i"
done

echo -e "$DB_ZONE_CONF" > "${OUTPUT_DIR}"/db.zone

DB_REV_CONF="$(envsubst '${CLUSTER_DOMAIN} ${CLUSTER_NAME} ${API_OCTET} ${DNS_OCTET} ${BM_GW_OCTET}' < "$PROJECT_DIR/dns/db.reverse.tmpl")"

for i in $(seq 0 $((NUM_MASTERS - 1))); do
    DB_REV_CONF="$DB_REV_CONF\n12$i IN  PTR $CLUSTER_NAME-master-$i.$CLUSTER_NAME.$CLUSTER_DOMAIN."
done

for i in $(seq 0 $((NUM_WORKERS - 1))); do
    DB_REV_CONF="$DB_REV_CONF\n13$i IN  PTR $CLUSTER_NAME-worker-$i.$CLUSTER_NAME.$CLUSTER_DOMAIN."
done

echo -e "$DB_REV_CONF" > "${OUTPUT_DIR}"/db.reverse

podman run -d --expose=53/udp --name "$CONTAINER_NAME" \
            -p "$DNS_IP:53:53/tcp" -p "$DNS_IP:53:53/udp" \
            -v "$OUTPUT_DIR:/etc/coredns:z" coredns/coredns:latest \
            -conf /etc/coredns/Corefile