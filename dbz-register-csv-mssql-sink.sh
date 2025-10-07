#!/bin/bash
set -e  # Exit on any error

# Database and Table Configuration
TARGET_DATABASE="stroke_predictions_training_data_v1"
TARGET_TABLE="kaggle_training_data"

echo "=== MSSQL CSV Data Load Configuration ==="
echo "Target Database: $TARGET_DATABASE"
echo "Target Table: $TARGET_TABLE"
echo "Source Topic: csv-data-topic"
echo ""

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
    echo "Please create $ENV_FILE with the required MSSQL connection variables."
    exit 1
fi

# Check if required environment variables are set
required_vars=("MSSQL_HOST" "MSSQL_PORT" "MSSQL_USER" "MSSQL_PASSWORD")
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
CONNECTOR_NAME="csv-mssql-sink-connector"
if curl -f -s -o /dev/null http://localhost:8083/connectors/$CONNECTOR_NAME; then
    echo "Deleting existing connector: $CONNECTOR_NAME"
    curl -s -X DELETE http://localhost:8083/connectors/$CONNECTOR_NAME
    sleep 2  # Wait a bit for cleanup
else
    echo "Connector $CONNECTOR_NAME does not exist, skipping deletion"
fi

echo "Registering MSSQL JDBC Sink Connector for CSV data..."

# Create temporary connector configuration file
CONNECTOR_CONFIG=$(cat << EOF
{
  "name": "$CONNECTOR_NAME",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "tasks.max": "1",
    "topics": "csv-data-topic",
    
    "connection.url": "jdbc:sqlserver://$MSSQL_HOST:$MSSQL_PORT;databaseName=$TARGET_DATABASE",
    "connection.user": "$MSSQL_USER",
    "connection.password": "$MSSQL_PASSWORD",
    
    "table.name.format": "$TARGET_TABLE",
    "auto.create": "true",
    "auto.evolve": "true",
    "insert.mode": "upsert",
    "pk.fields": "id",
    "pk.mode": "record_value",
    "delete.enabled": "false",
    
    "max.retries": "3",
    "retry.backoff.ms": "1000",
    
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false"
  }
}
EOF
)

# Write configuration to temporary file
echo "$CONNECTOR_CONFIG" > /tmp/csv-mssql-sink.json

# Register the connector
echo "Registering connector: $CONNECTOR_NAME"

response=$(curl -s -o response.json -w "%{http_code}" -X POST http://localhost:8083/connectors/ \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data "@/tmp/csv-mssql-sink.json")

if [ "$response" -eq 201 ] || [ "$response" -eq 409 ]; then
    echo "✓ Successfully registered $CONNECTOR_NAME"
    cat response.json
    echo ""
else
    echo "✗ Failed to register $CONNECTOR_NAME (HTTP $response)"
    cat response.json
    echo ""
    rm -f response.json /tmp/csv-mssql-sink.json
    exit 1
fi

# Cleanup
rm -f response.json /tmp/csv-mssql-sink.json

echo "MSSQL JDBC sink connector registered successfully!"

# Verify connector status
echo "Verifying connector status..."
sleep 5  # Give the connector a moment to start

status=$(curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq -r '.connector.state' 2>/dev/null || echo "UNKNOWN")
echo "Connector $CONNECTOR_NAME status: $status"

# Display tasks status too
tasks=$(curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq -r '.tasks[].state' 2>/dev/null || echo "UNKNOWN")
echo "Tasks status: $tasks"

echo ""
echo "=== Setup Summary ==="
echo "Database: $TARGET_DATABASE"
echo "Table: $TARGET_TABLE"
echo "Data will be loaded from Kafka topic: csv-data-topic"
echo "MSSQL sink setup completed!"
