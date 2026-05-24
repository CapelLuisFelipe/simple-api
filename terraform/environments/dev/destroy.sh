#!/bin/bash
set -e

echo "=== Removendo SNS do state (prevent_destroy) ==="
terraform state rm aws_sns_topic.alerts 2>/dev/null || true
terraform state rm aws_sns_topic_subscription.email 2>/dev/null || true

echo "=== Destruindo infraestrutura ==="
terraform destroy "$@"
