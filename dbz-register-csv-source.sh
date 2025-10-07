curl -X PUT http://localhost:8083/connectors/csv-file-source-connector/config \
  -H "Content-Type: application/json" \
  -d '{
    "connector.class": "io.streamthoughts.kafka.connect.filepulse.source.FilePulseSourceConnector",
    "topic": "csv-data-topic",
    "tasks.max": "1",
    
    "fs.listing.class": "io.streamthoughts.kafka.connect.filepulse.fs.LocalFSDirectoryListing",
    "fs.listing.directory.path": "/data",
    "fs.listing.interval.ms": "10000",
    "fs.listing.filters": "io.streamthoughts.kafka.connect.filepulse.fs.filter.RegexFileListFilter",
    "file.filter.regex.pattern": ".*\\.csv$",
    
    "fs.cleanup.policy.class": "io.streamthoughts.kafka.connect.filepulse.fs.clean.LogCleanupPolicy",
    "fs.cleanup.policy.triggered.on": "COMMITTED",
    
    "tasks.reader.class": "io.streamthoughts.kafka.connect.filepulse.fs.reader.LocalRowFileInputReader",
    
    "tasks.file.status.storage.class": "io.streamthoughts.kafka.connect.filepulse.state.KafkaFileObjectStateBackingStore",
    "tasks.file.status.storage.bootstrap.servers": "kafka:9092",
    "tasks.file.status.storage.topic": "connect-file-pulse-status",
    "tasks.file.status.storage.topic.partitions": "1",
    "tasks.file.status.storage.topic.replication.factor": "1",
    
    "file.parsing.csv.first.row.as.header": "true",
    "file.parsing.csv.separator": ",",
    "file.parsing.csv.ignore.empty.lines": "true",
    "file.parsing.csv.trim.column": "true",
    
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false"
  }'
