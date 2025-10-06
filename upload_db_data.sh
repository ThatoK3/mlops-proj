#!/bin/bash
source .env
mysql -u root -p${MYSQL_ROOT_PASSWORD} -h ${INSTANCE_PRIVATE_IP} stroke_predictions < stroke_predictions.sql
