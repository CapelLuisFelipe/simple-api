const { Client } = require('pg');
const express = require('express');
const path = require('path');
const os = require('os');

(async () => {
    const app = express()
    const port = process.env.API_PORT || 3000
    let i = 0

    app.listen(port, () => {
        console.log(`API iniciada. Escutando PORT ${port}`)
    })

    app.use((req, res, next) => {
        i++;
        next();
    })

    // ── original routes (unchanged) ──────────────────────────────────────────

    app.get('/', async (req, res) => {
        const response = { 'message': "API OK!", 'request_id': i }
        console.log(response)
        res.send(response)
    })

    app.get('/connect', async (req, res) => {
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

            const response = { 'message': "Conectado ao banco", 'version': version, 'request_id': i }
            console.log(response)
            res.send(response)
        } catch (e) {
            const error = { 'message': 'Erro ao se conectar ao banco', 'request_id': i }
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

    // Static files last — serves /style.css, /app.js, /assets/*
    // Must come after explicit routes so GET / returns JSON, not index.html
    app.use(express.static(path.join(__dirname, '../public')))
})()
