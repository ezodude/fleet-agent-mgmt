export const meta = { name: 'board-check-v0', description: 'An invented two-agent workflow', phases: [{ title: 'Understand' }] }
phase('Understand')
await Promise.all([agent('read the board data'), agent('read the pane API')])
