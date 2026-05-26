const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query, queryOne, run } = require('../db');
const SECRET = process.env.JWT_SECRET || 'school_billing_secret_2024';

function auth(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  try { req.user = jwt.verify(token, SECRET); next(); }
  catch { res.status(401).json({ error: 'Invalid token' }); }
}

function adminOnly(req, res, next) {
  if (req.user?.role !== 'admin') return res.status(403).json({ error: 'Admin access required' });
  next();
}

router.post('/login', (req, res) => {
  const { username, password } = req.body;
  const user = queryOne('SELECT * FROM users WHERE username = ? AND active = 1', [username]);
  if (!user || !bcrypt.compareSync(password, user.password))
    return res.status(401).json({ error: 'Invalid credentials' });
  const token = jwt.sign({ id: user.id, role: user.role, name: user.name }, SECRET, { expiresIn: '12h' });
  res.json({ token, role: user.role, name: user.name, id: user.id });
});

router.get('/users', auth, (req, res) => {
  res.json(query('SELECT id,username,name,role,active FROM users'));
});

router.post('/users', auth, adminOnly, (req, res) => {
  const { username, password, role, name } = req.body;
  const hash = bcrypt.hashSync(password, 10);
  const r = run('INSERT INTO users (username,password,role,name) VALUES (?,?,?,?)', [username, hash, role, name]);
  res.json({ id: r.lastInsertRowid });
});

router.put('/users/:id', auth, adminOnly, (req, res) => {
  const { name, role, active, password } = req.body;
  if (password) {
    const hash = bcrypt.hashSync(password, 10);
    run('UPDATE users SET name=?,role=?,active=?,password=? WHERE id=?', [name, role, active, hash, req.params.id]);
  } else {
    run('UPDATE users SET name=?,role=?,active=? WHERE id=?', [name, role, active, req.params.id]);
  }
  res.json({ success: true });
});

module.exports = router;
