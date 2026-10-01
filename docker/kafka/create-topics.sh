#!/bin/bash
set -euo pipefail

# Topics are created explicitly so partitioning is reproducible in every environment.
topics=(
  orders.created
  orders.confirmed
  orders.preparing
  orders.ready
  orders.out_for_delivery
  orders.delivered
  orders.cancelled
  payments.completed
  payments.failed
  delivery.assigned
  delivery.completed
)

for topic in "${topics[@]}"; do
  /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server kafka:19092 \
    --create \
    --if-not-exists \
    --topic "$topic" \
    --partitions 3 \
    --replication-factor 1
done

/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --list
