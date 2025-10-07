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
    echo "Please create $ENV_FILE with the required CSV connection variables."
    exit 1
fi

# Check if required environment variables are set
required_vars=("CSV_DATA_DIRECTORY" "CSV_TOPIC_NAME")
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
CONNECTOR_NAME="csv-file-source-connector"
if curl -f -s -o /dev/null http://localhost:8083/connectors/$CONNECTOR_NAME; then
    echo "Deleting existing connector: $CONNECTOR_NAME"
    curl -s -X DELETE http://localhost:8083/connectors/$CONNECTOR_NAME
    sleep 2  # Wait a bit for cleanup
else
    echo "Connector $CONNECTOR_NAME does not exist, skipping deletion"
fi

echo "Registering FilePulse CSV Source Connector..."

# Create temporary connector configuration file
CONNECTOR_CONFIG=$(cat << EOF
{
  "name": "$CONNECTOR_NAME",
  "config": {
    "connector.class": "io.streamthoughts.kafka.connect.filepulse.source.FilePulseSourceConnector",
    "topic": "$CSV_TOPIC_NAME",
    "tasks.max": "1",
    
    "fs.listing.class": "io.streamthoughts.kafka.connect.filepulse.fs.LocalFSDirectoryListing",
    "fs.listing.directory.path": "$CSV_DATA_DIRECTORY",
    "fs.listing.interval.ms": "5000",
    "fs.listing.filters": "io.streamthoughts.kafka.connect.filepulse.fs.filter.RegexFileListFilter",
    "file.filter.regex.pattern": ".*\\\\.csv$",
    
    "fs.cleanup.policy.class": "io.streamthoughts.kafka.connect.filepulse.fs.clean.LogCleanupPolicy",
    "fs.cleanup.policy.triggered.on": "COMMITTED",
    
    "tasks.reader.class": "io.streamthoughts.kafka.connect.filepulse.fs.reader.LocalRowFileInputReader",
    
    "tasks.file.status.storage.class": "io.streamthoughts.kafka.connect.filepulse.state.KafkaFileObjectStateBackingStore",
    "tasks.file.status.storage.bootstrap.servers": "kafka:9092",
    "tasks.file.status.storage.topic": "connect-file-pulse-status-reset",
    "tasks.file.status.storage.topic.partitions": "1",
    "tasks.file.status.storage.topic.replication.factor": "1",
    
    "skip.headers": "1",
    "read.max.wait.ms": "10000",
    
    "filters": "ParseLine",
    "filters.ParseLine.type": "io.streamthoughts.kafka.connect.filepulse.filter.DelimitedRowFilter",
    "filters.ParseLine.separator": ",",
    "filters.ParseLine.trimColumn": "true",
    "filters.ParseLine.extractColumnName": "headers",
    
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false"
  }
}
EOF
)

# Write configuration to temporary file
echo "$CONNECTOR_CONFIG" > /tmp/csv-connector.json

# Register the connector
echo "Registering connector: $CONNECTOR_NAME"

response=$(curl -s -o response.json -w "%{http_code}" -X POST http://localhost:8083/connectors/ \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data "@/tmp/csv-connector.json")

if [ "$response" -eq 201 ] || [ "$response" -eq 409 ]; then
    echo "✓ Successfully registered $CONNECTOR_NAME"
    cat response.json
    echo ""
else
    echo "✗ Failed to register $CONNECTOR_NAME (HTTP $response)"
    cat response.json
    echo ""
    rm -f response.json /tmp/csv-connector.json
    exit 1
fi

# Cleanup
rm -f response.json /tmp/csv-connector.json

echo "FilePulse CSV source connector registered successfully!"

# Verify connector status
echo "Verifying connector status..."
sleep 5  # Give the connector a moment to start

status=$(curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq -r '.connector.state' 2>/dev/null || echo "UNKNOWN")
echo "Connector $CONNECTOR_NAME status: $status"

# Display tasks status too
tasks=$(curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq -r '.tasks[].state' 2>/dev/null || echo "UNKNOWN")
echo "Tasks status: $tasks"

echo "CSV source setup completed!"
