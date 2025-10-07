curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "csv-mssql-sink-connector",
    "config": {
      "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
      "tasks.max": "1",
      "topics": "csv-data-topic",
      
      "connection.url": "jdbc:sqlserver://54.198.226.213:1433;databaseName=stroke_predictions_training_data_v1",
      "connection.user": "sa",
      "connection.password": "YourStrong!Pass123",
      
      "auto.create": "true",
      "auto.evolve": "true",
      "insert.mode": "upsert",
      "pk.fields": "id",
      "pk.mode": "record_value",
      
      "key.converter": "org.apache.kafka.connect.storage.StringConverter",
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter.schemas.enable": "false"
    }
  }'
