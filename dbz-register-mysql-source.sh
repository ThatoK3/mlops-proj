#!/bin/bash
set -e  # Exit on any error

# Define custom environment file
ENV_FILE=".env"

# Load environment variables from custom file
if [ -f "$ENV_FILE" ]; then
    echo "Loading environment variables from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Error: $ENV_FILE file not found!"
    echo "Please create $ENV_FILE with the required MySQL connection variables."
    exit 1
fi

# Check if required environment variables are set
required_vars=("MYSQL_HOST" "MYSQL_PORT" "MYSQL_USER" "MYSQL_PASSWORD" "MYSQL_SERVER_ID" "MYSQL_SERVER_NAME" "MYSQL_DATABASE")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in $ENV_FILE!"
        exit 1
    fi
done

# Check if Connect REST API is available
if ! curl -f -s -o /dev/null http://localhost:8083/connectors/; then
    echo "Error: Kafka Connect REST API is not available at http://localhost:8083/"
    echo "Please ensure Kafka Connect is running and accessible."
    exit 1
fi

# Delete existing connector if it exists
CONNECTOR_NAME="stroke-predictions-connector"
if curl -f -s -o /dev/null http://localhost:8083/connectors/$CONNECTOR_NAME; then
    echo "Deleting existing connector: $CONNECTOR_NAME"
    curl -s -X DELETE http://localhost:8083/connectors/$CONNECTOR_NAME
    sleep 2  # Wait a bit for cleanup
else
    echo "Connector $CONNECTOR_NAME does not exist, skipping deletion"
fi

echo "Registering Debezium MySQL Source Connector with Avro..."

# Create temporary connector configuration file
CONNECTOR_CONFIG=$(cat << EOF
{
  "name": "$CONNECTOR_NAME",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",
    "database.hostname": "$MYSQL_HOST",
    "database.port": "$MYSQL_PORT",
    "database.user": "root",
    "database.password": "$MYSQL_ROOT_PASSWORD",
    "database.server.id": "$MYSQL_SERVER_ID",
    "database.server.name": "$MYSQL_SERVER_NAME",
    "database.include.list": "$MYSQL_DATABASE",
    "database.history.kafka.bootstrap.servers": "kafka:9092",
    "database.history.kafka.topic": "schema-changes.$MYSQL_DATABASE",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}
EOF
)

# Write configuration to temporary file
echo "$CONNECTOR_CONFIG" > /tmp/debezium-connector.json

# Register the connector
echo "Registering connector: $CONNECTOR_NAME"

response=$(curl -s -o response.json -w "%{http_code}" -X POST http://localhost:8083/connectors/ \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data "@/tmp/debezium-connector.json")

if [ "$response" -eq 201 ] || [ "$response" -eq 409 ]; then
    echo "✓ Successfully registered $CONNECTOR_NAME"
    cat response.json
    echo ""
else
    echo "✗ Failed to register $CONNECTOR_NAME (HTTP $response)"
    cat response.json
    echo ""
    rm -f response.json /tmp/debezium-connector.json
    exit 1
fi

# Cleanup
rm -f response.json /tmp/debezium-connector.json

echo "Debezium MySQL source connector registered successfully!"

# Verify connector status
echo "Verifying connector status..."
sleep 5  # Give the connector a moment to start

status=$(curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq -r '.connector.state' 2>/dev/null || echo "UNKNOWN")
echo "Connector $CONNECTOR_NAME status: $status"

# Display tasks status too
tasks=$(curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq -r '.tasks[].state' 2>/dev/null || echo "UNKNOWN")
echo "Tasks status: $tasks"

echo "Setup completed!"
