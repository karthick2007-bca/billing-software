const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const path = require('path');
const { initDb } = require('./db');

const app = express();
const SECRET = process.env.JWT_SECRET || 'school_billing_secret_2024';

app.use(cors());
app.use(express.json());

function auth(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  try {
    req.user = jwt.verify(token, SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

app.use('/api/auth', require('./routes/auth'));
app.use('/api/students', auth, require('./routes/students'));
app.use('/api/fees', auth, require('./routes/fees'));
app.use('/api/challans', auth, require('./routes/challans'));
app.use('/api/payments', auth, require('./routes/payments'));
app.use('/api/reports', auth, require('./routes/reports'));
app.use('/api/inventory', auth, require('./routes/inventory'));
app.get('/api/health', (req, res) => res.json({ status: 'ok' }));

// Serve Flutter web build
app.use(express.static(path.join(__dirname, 'web')));
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'web', 'index.html'));
});

const PORT = process.env.PORT || 3000;

initDb().then(() => {
  app.listen(PORT, '0.0.0.0', () => {
    const { networkInterfaces } = require('os');
    const nets = networkInterfaces();
    let localIp = 'localhost';
    for (const iface of Object.values(nets)) {
      for (const net of iface) {
        if (net.family === 'IPv4' && !net.internal) { localIp = net.address; break; }
      }
    }
    console.log(`School Billing Server running on:`);
    console.log(`  Local:   http://localhost:${PORT}`);
    console.log(`  Network: http://${localIp}:${PORT}`);
  });
}).catch(err => {
  console.error('Failed to initialize database:', err);
  process.exit(1);
});
