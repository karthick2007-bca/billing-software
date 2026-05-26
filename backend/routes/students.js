const router = require('express').Router();
const { query, queryOne, run } = require('../db');

router.get('/', (req, res) => {
  const { academic_year_id, class: cls, section, search } = req.query;
  let q = 'SELECT * FROM students WHERE 1=1';
  const params = [];
  if (academic_year_id) { q += ' AND academic_year_id=?'; params.push(academic_year_id); }
  if (cls) { q += ' AND class=?'; params.push(cls); }
  if (section) { q += ' AND section=?'; params.push(section); }
  if (search) { q += ' AND (name LIKE ? OR admission_no LIKE ?)'; params.push(`%${search}%`, `%${search}%`); }
  res.json(query(q, params));
});

router.get('/:id', (req, res) => {
  const s = queryOne('SELECT * FROM students WHERE id=?', [req.params.id]);
  if (!s) return res.status(404).json({ error: 'Not found' });
  res.json(s);
});

router.post('/', (req, res) => {
  const { admission_no, name, class: cls, section, roll_no, dob, gender,
    parent_name, parent_phone, parent_email, address, sibling_group_id, academic_year_id } = req.body;
  const r = run(
    `INSERT INTO students (admission_no,name,class,section,roll_no,dob,gender,parent_name,parent_phone,parent_email,address,sibling_group_id,academic_year_id)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
    [admission_no, name, cls, section, roll_no || null, dob || null, gender || null,
     parent_name || null, parent_phone || null, parent_email || null, address || null,
     sibling_group_id || null, academic_year_id]
  );
  res.json({ id: r.lastInsertRowid });
});

router.put('/:id', (req, res) => {
  const { name, class: cls, section, roll_no, dob, gender,
    parent_name, parent_phone, parent_email, address, sibling_group_id, active } = req.body;
  run(
    `UPDATE students SET name=?,class=?,section=?,roll_no=?,dob=?,gender=?,
     parent_name=?,parent_phone=?,parent_email=?,address=?,sibling_group_id=?,active=? WHERE id=?`,
    [name, cls, section, roll_no || null, dob || null, gender || null,
     parent_name || null, parent_phone || null, parent_email || null,
     address || null, sibling_group_id || null, active ?? 1, req.params.id]
  );
  res.json({ success: true });
});

router.delete('/:id', (req, res) => {
  run('UPDATE students SET active=0 WHERE id=?', [req.params.id]);
  res.json({ success: true });
});

module.exports = router;
