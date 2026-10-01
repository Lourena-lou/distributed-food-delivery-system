param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("mongodb", "mysql")]
    [string]$Backend
)

$ErrorActionPreference = "Stop"
$dockerDirectory = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $dockerDirectory ".env"
$composeFile = Join-Path $dockerDirectory "compose.$Backend.yml"
$expectedTopics = @(
    "orders.created",
    "orders.confirmed",
    "orders.preparing",
    "orders.ready",
    "orders.out_for_delivery",
    "orders.delivered",
    "orders.cancelled",
    "payments.completed",
    "payments.failed",
    "delivery.assigned",
    "delivery.completed"
)

$topicOutput = & docker compose --env-file $environmentFile --file $composeFile exec -T kafka `
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:19092 --describe
if ($LASTEXITCODE -ne 0) {
    throw "Kafka topic inspection failed for the $Backend stack."
}

foreach ($topic in $expectedTopics) {
    $topicSummary = @($topicOutput | Where-Object {
        $_ -match "^Topic: $([regex]::Escape($topic))\s" -and $_ -match "PartitionCount: 3"
    })
    if ($topicSummary.Count -ne 1) {
        throw "Topic '$topic' does not have the expected three partitions."
    }
}

Write-Host "All eleven Kafka topics exist with three partitions each."
