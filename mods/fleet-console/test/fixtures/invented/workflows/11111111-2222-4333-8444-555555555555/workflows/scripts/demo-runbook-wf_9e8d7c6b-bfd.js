export const meta = { name: 'demo-runbook', description: 'An invented one-agent workflow', phases: [{ title: 'Runbook' }] }
phase('Runbook')
await agent('write the runbook')
