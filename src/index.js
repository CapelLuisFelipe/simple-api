const { Client } = require('pg');
const express = require('express');
const path = require('path');
const os = require('os');
const { ECSClient, DescribeServicesCommand } = require('@aws-sdk/client-ecs');
const { CloudWatchClient, DescribeAlarmHistoryCommand } = require('@aws-sdk/client-cloudwatch');
const { ApplicationAutoScalingClient, DescribeScalingActivitiesCommand } = require('@aws-sdk/client-application-auto-scaling');

const REGION   = process.env.AWS_REGION || 'us-east-1';
const CLUSTER  = process.env.ECS_CLUSTER_NAME || 'simple-api-cluster';
const SVC_NAME = process.env.ECS_SERVICE_NAME || 'simple-api-service';

const ecsClient = new ECSClient({ region: REGION });
const cwClient  = new CloudWatchClient({ region: REGION });
const aasClient = new ApplicationAutoScalingClient({ region: REGION });

(async () => {
    const app = express()
    const port = process.env.API_PORT || 3000
    let i = 0

    app.listen(port, () => {
        console.log(`API iniciada. Escutando PORT ${port}`)
    })

    // ── original routes (unchanged) ──────────────────────────────────────────

    app.get('/', async (req, res) => {
        i++;
        const response = { message: 'API OK TESTE1!', task: os.hostname(), task_request_count: i }
        console.log(response)
        res.send(response)
    })

    app.get('/connect', async (req, res) => {
        i++;
        try {
            const client = new Client({
                user: process.env.DB_USER,
                host: process.env.DB_HOST,
                database: process.env.DB_DATABASE,
                password: process.env.DB_PASSWORD,
                port: process.env.DB_PORT || 5432,
            })
            await client.connect()

            const result = await client.query('SELECT version()')
            const version = result.rows[0].version

            await client.end()

            const response = { message: 'Conectado ao banco', version, task: os.hostname(), task_request_count: i }
            console.log(response)
            res.send(response)
        } catch (e) {
            const error = { message: 'Erro ao se conectar ao banco', task: os.hostname(), task_request_count: i }
            console.log(error)
            console.log(e)

            res.status(500);
            res.send(error)
        }
    })

    // ── demo routes ───────────────────────────────────────────────────────────

    // Visual dashboard
    app.get('/dashboard', (req, res) => {
        res.sendFile(path.join(__dirname, '../public/index.html'))
    })

    // CPU stress — FOR DEMO ONLY: triggers ECS Auto Scaling by saturating CPU.
    // Synchronous loop blocks the event loop intentionally to maximize per-container
    // CPU metric. Max 30 s to avoid ALB health-check cascade failures.
    app.get('/stress', (req, res) => {
        const MAX_SECONDS = 30
        const seconds = Math.min(Math.max(parseInt(req.query.seconds) || 5, 1), MAX_SECONDS)
        const deadline = Date.now() + seconds * 1000

        // CPU-bound loop — no heap growth, no I/O
        while (Date.now() < deadline) {
            Math.sqrt(Math.random() * 999999)
        }

        res.json({
            status: 'CPU stress completed',
            durationSeconds: seconds,
            hostname: os.hostname(),
            timestamp: new Date().toISOString(),
            message: 'Controlled CPU stress executed for ECS Auto Scaling demo',
        })
    })

    // ── observability routes ──────────────────────────────────────────────────

    app.get('/obs/status', async (req, res) => {
        try {
            const { services } = await ecsClient.send(
                new DescribeServicesCommand({ cluster: CLUSTER, services: [SVC_NAME] })
            )
            const s = services[0]
            res.json({
                desired:   s.desiredCount,
                running:   s.runningCount,
                pending:   s.pendingCount,
                status:    s.status,
                updatedAt: s.deployments?.[0]?.updatedAt,
            })
        } catch (e) {
            res.status(500).json({ error: e.message })
        }
    })

    app.get('/obs/scaling-events', async (req, res) => {
        try {
            const { ScalingActivities } = await aasClient.send(
                new DescribeScalingActivitiesCommand({
                    ServiceNamespace: 'ecs',
                    ResourceId:       `service/${CLUSTER}/${SVC_NAME}`,
                    MaxResults:       10,
                })
            )
            res.json({
                events: ScalingActivities.map(a => ({
                    description: a.Description,
                    cause:       a.Cause,
                    status:      a.StatusCode,
                    startTime:   a.StartTime,
                }))
            })
        } catch (e) {
            res.status(500).json({ error: e.message })
        }
    })

    app.get('/obs/alarm-history', async (req, res) => {
        try {
            const alarms = ['simple-api-cpu-high', 'simple-api-cpu-low']
            const results = await Promise.all(alarms.map(name =>
                cwClient.send(new DescribeAlarmHistoryCommand({
                    AlarmName:       name,
                    HistoryItemType: 'StateUpdate',
                    MaxRecords:      10,
                }))
            ))
            const items = results
                .flatMap((r, idx) => r.AlarmHistoryItems.map(item => {
                    let summary = {}
                    try { summary = JSON.parse(item.HistoryData) } catch (_) {}
                    const newState  = summary.newState?.stateValue || '?'
                    const reason    = summary.newState?.stateReason || ''
                    const metric    = reason.match(/\[([0-9.]+)\]/)
                    return {
                        alarm:    alarms[idx],
                        state:    newState,
                        metric:   metric ? parseFloat(metric[1]).toFixed(1) + '%' : null,
                        ts:       item.Timestamp,
                    }
                }))
                .sort((a, b) => new Date(b.ts) - new Date(a.ts))
                .slice(0, 15)
            res.json({ items })
        } catch (e) {
            res.status(500).json({ error: e.message })
        }
    })

    // Static files last — serves /style.css, /app.js, /assets/*
    // Must come after explicit routes so GET / returns JSON, not index.html
    app.use(express.static(path.join(__dirname, '../public')))
})()
