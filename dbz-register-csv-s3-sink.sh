#!/bin/bash
set -e  # Exit on error

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "Error: .env file not found!"
    exit 1
fi

# Check required environment variables
required_vars=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_REGION" "S3_BUCKET")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env file!"
        exit 1
    fi
done

# Check if Connect REST API is available
if ! curl -f -s -o /dev/null http://localhost:8083/connectors/; then
    echo "Error: Kafka Connect REST API is not available at http://localhost:8083/"
    exit 1
fi

# Connector name
CONNECTOR_NAME="s3-sink-csv-data"

# Delete existing connector if exists
if curl -f -s -o /dev/null http://localhost:8083/connectors/$CONNECTOR_NAME; then
    echo "Deleting existing connector: $CONNECTOR_NAME"
    curl -s -X DELETE http://localhost:8083/connectors/$CONNECTOR_NAME
    sleep 2
fi

echo "Registering S3 Sink Connector for CSV data..."

# Register S3 Sink with JSON format and simpler configuration
response=$(curl -s -o response.json -w "%{http_code}" -X POST http://localhost:8083/connectors/ \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'"$CONNECTOR_NAME"'",
    "config": {
      "connector.class": "io.confluent.connect.s3.S3SinkConnector",
      "tasks.max": "1",
      "topics": "csv-data-topic",

      "s3.bucket.name": "'"$S3_BUCKET"'",
      "s3.region": "'"$AWS_REGION"'",

      "aws.access.key.id": "'"$AWS_ACCESS_KEY_ID"'",
      "aws.secret.access.key": "'"$AWS_SECRET_ACCESS_KEY"'",

      "format.class": "io.confluent.connect.s3.format.json.JsonFormat",
      "storage.class": "io.confluent.connect.s3.storage.S3Storage",
      "flush.size": "100",
      "rotate.interval.ms": "60000",

      "key.converter": "org.apache.kafka.connect.storage.StringConverter",
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter.schemas.enable": "false",

      "partitioner.class": "io.confluent.connect.storage.partitioner.DefaultPartitioner",
      "locale": "en-US",
      "timezone": "UTC"
    }
  }')

if [ "$response" -eq 201 ] || [ "$response" -eq 409 ]; then
    echo "✓ Successfully registered $CONNECTOR_NAME"
    cat response.json
    echo ""
else
    echo "✗ Failed to register $CONNECTOR_NAME (HTTP $response)"
    cat response.json
    echo ""
    rm -f response.json
    exit 1
fi

rm -f response.json

# Verify connector status
echo "Verifying connector status..."
sleep 5

status=$(curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq -r '.connector.state' 2>/dev/null || echo "UNKNOWN")
echo "Connector $CONNECTOR_NAME status: $status"

# Display tasks status too
tasks=$(curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq -r '.tasks[].state' 2>/dev/null || echo "UNKNOWN")
echo "Tasks status: $tasks"

echo "S3 CSV sink setup completed!"
