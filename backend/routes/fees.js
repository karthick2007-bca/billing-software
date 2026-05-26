const router = require('express').Router();
const { query, queryOne, run } = require('../db');

// Academic Years
router.get('/academic-years', (req, res) => res.json(query('SELECT * FROM academic_years ORDER BY id DESC')));

router.post('/academic-years', (req, res) => {
  const { label, start_date, end_date, is_current } = req.body;
  if (is_current) run('UPDATE academic_years SET is_current=0');
  const r = run('INSERT INTO academic_years (label,start_date,end_date,is_current) VALUES (?,?,?,?)',
    [label, start_date, end_date, is_current ? 1 : 0]);
  res.json({ id: r.lastInsertRowid });
});

router.put('/academic-years/:id/set-current', (req, res) => {
  run('UPDATE academic_years SET is_current=0');
  run('UPDATE academic_years SET is_current=1 WHERE id=?', [req.params.id]);
  res.json({ success: true });
});

// Fee Types
router.get('/types', (req, res) => {
  res.json(query('SELECT * FROM fee_types WHERE academic_year_id=?', [req.query.academic_year_id]));
});

router.post('/types', (req, res) => {
  const { name, category, academic_year_id } = req.body;
  const r = run('INSERT INTO fee_types (name,category,academic_year_id) VALUES (?,?,?)', [name, category, academic_year_id]);
  res.json({ id: r.lastInsertRowid });
});

router.delete('/types/:id', (req, res) => {
  run('DELETE FROM fee_types WHERE id=?', [req.params.id]);
  res.json({ success: true });
});

// Fee Structures
router.get('/structures', (req, res) => {
  const { academic_year_id, class: cls } = req.query;
  let q = `SELECT fs.*, ft.name as fee_type_name, ft.category FROM fee_structures fs
    JOIN fee_types ft ON fs.fee_type_id=ft.id WHERE fs.academic_year_id=?`;
  const params = [academic_year_id];
  if (cls) { q += ' AND fs.class=?'; params.push(cls); }
  res.json(query(q, params));
});

router.post('/structures', (req, res) => {
  const { fee_type_id, class: cls, section, period_type, period_label, amount, due_date, academic_year_id } = req.body;
  const r = run(
    'INSERT INTO fee_structures (fee_type_id,class,section,period_type,period_label,amount,due_date,academic_year_id) VALUES (?,?,?,?,?,?,?,?)',
    [fee_type_id, cls, section || null, period_type, period_label, amount, due_date || null, academic_year_id]
  );
  res.json({ id: r.lastInsertRowid });
});

router.put('/structures/:id', (req, res) => {
  const { amount, due_date } = req.body;
  run('UPDATE fee_structures SET amount=?,due_date=? WHERE id=?', [amount, due_date || null, req.params.id]);
  res.json({ success: true });
});

router.delete('/structures/:id', (req, res) => {
  run('DELETE FROM fee_structures WHERE id=?', [req.params.id]);
  res.json({ success: true });
});

// Discounts
router.get('/discounts', (req, res) => {
  res.json(query('SELECT * FROM discounts WHERE academic_year_id=?', [req.query.academic_year_id]));
});

router.post('/discounts', (req, res) => {
  const { name, type, value, scope, academic_year_id } = req.body;
  const r = run('INSERT INTO discounts (name,type,value,scope,academic_year_id) VALUES (?,?,?,?,?)',
    [name, type, value, scope, academic_year_id]);
  res.json({ id: r.lastInsertRowid });
});

router.delete('/discounts/:id', (req, res) => {
  run('DELETE FROM discounts WHERE id=?', [req.params.id]);
  res.json({ success: true });
});

// Student Discounts
router.get('/student-discounts/:studentId', (req, res) => {
  res.json(query(
    `SELECT sd.*, d.name, d.type, d.value, d.scope FROM student_discounts sd
     JOIN discounts d ON sd.discount_id=d.id WHERE sd.student_id=?`,
    [req.params.studentId]
  ));
});

router.post('/student-discounts', (req, res) => {
  const { student_id, discount_id, fee_structure_id } = req.body;
  const r = run('INSERT INTO student_discounts (student_id,discount_id,fee_structure_id) VALUES (?,?,?)',
    [student_id, discount_id, fee_structure_id || null]);
  res.json({ id: r.lastInsertRowid });
});

router.delete('/student-discounts/:id', (req, res) => {
  run('DELETE FROM student_discounts WHERE id=?', [req.params.id]);
  res.json({ success: true });
});

module.exports = router;
