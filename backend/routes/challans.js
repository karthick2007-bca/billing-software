const router = require('express').Router();
const { query, queryOne, run } = require('../db');

function calcDiscount(studentId, feeStructureId, originalAmount) {
  const discounts = query(
    `SELECT d.type, d.value FROM student_discounts sd
     JOIN discounts d ON sd.discount_id=d.id
     WHERE sd.student_id=? AND (sd.fee_structure_id=? OR sd.fee_structure_id IS NULL)`,
    [studentId, feeStructureId]
  );
  let total = 0;
  for (const d of discounts) {
    total += d.type === 'percentage' ? (originalAmount * d.value / 100) : d.value;
  }
  return Math.min(total, originalAmount);
}

function nextChallanNo() {
  const last = queryOne('SELECT challan_no FROM challans ORDER BY id DESC LIMIT 1');
  if (!last) return 'CH-0001';
  const num = parseInt(last.challan_no.split('-')[1]) + 1;
  return `CH-${String(num).padStart(4, '0')}`;
}

router.post('/generate', (req, res) => {
  const { student_id, academic_year_id } = req.body;
  const student = queryOne('SELECT * FROM students WHERE id=?', [student_id]);
  if (!student) return res.status(404).json({ error: 'Student not found' });

  const structures = query(
    `SELECT * FROM fee_structures WHERE academic_year_id=? AND class=? AND (section=? OR section IS NULL OR section='')`,
    [academic_year_id, student.class, student.section]
  );

  const generated = [];
  for (const fs of structures) {
    const existing = queryOne(
      'SELECT id FROM challans WHERE student_id=? AND fee_structure_id=? AND academic_year_id=?',
      [student_id, fs.id, academic_year_id]
    );
    if (existing) continue;
    const discount = calcDiscount(student_id, fs.id, fs.amount);
    const net = fs.amount - discount;
    const r = run(
      `INSERT INTO challans (challan_no,student_id,academic_year_id,fee_structure_id,original_amount,discount_amount,net_amount,due_date)
       VALUES (?,?,?,?,?,?,?,?)`,
      [nextChallanNo(), student_id, academic_year_id, fs.id, fs.amount, discount, net, fs.due_date || null]
    );
    generated.push(r.lastInsertRowid);
  }
  res.json({ generated: generated.length, ids: generated });
});

router.get('/', (req, res) => {
  const { student_id, academic_year_id, status } = req.query;
  let q = `SELECT c.*, s.name as student_name, s.class, s.section, s.admission_no,
    fs.period_label, fs.period_type, ft.name as fee_type_name, ft.category
    FROM challans c
    JOIN students s ON c.student_id=s.id
    JOIN fee_structures fs ON c.fee_structure_id=fs.id
    JOIN fee_types ft ON fs.fee_type_id=ft.id WHERE 1=1`;
  const params = [];
  if (student_id) { q += ' AND c.student_id=?'; params.push(student_id); }
  if (academic_year_id) { q += ' AND c.academic_year_id=?'; params.push(academic_year_id); }
  if (status) { q += ' AND c.status=?'; params.push(status); }
  res.json(query(q, params));
});

router.get('/:id', (req, res) => {
  const c = queryOne(
    `SELECT c.*, s.name as student_name, s.class, s.section, s.admission_no,
     s.parent_name, s.parent_phone, fs.period_label, fs.period_type, ft.name as fee_type_name
     FROM challans c JOIN students s ON c.student_id=s.id
     JOIN fee_structures fs ON c.fee_structure_id=fs.id
     JOIN fee_types ft ON fs.fee_type_id=ft.id WHERE c.id=?`,
    [req.params.id]
  );
  if (!c) return res.status(404).json({ error: 'Not found' });
  res.json(c);
});

router.put('/:id/waive', (req, res) => {
  run("UPDATE challans SET status='waived' WHERE id=?", [req.params.id]);
  res.json({ success: true });
});

router.post('/carry-forward', (req, res) => {
  const { from_year_id, to_year_id } = req.body;
  const unpaid = query(
    "SELECT * FROM challans WHERE academic_year_id=? AND status IN ('pending','partial')",
    [from_year_id]
  );
  for (const c of unpaid) {
    run(
      `INSERT INTO challans (challan_no,student_id,academic_year_id,fee_structure_id,original_amount,discount_amount,net_amount,due_date,carry_forward)
       VALUES (?,?,?,?,?,?,?,?,1)`,
      [nextChallanNo(), c.student_id, to_year_id, c.fee_structure_id, c.net_amount, 0, c.net_amount, null]
    );
  }
  res.json({ carried: unpaid.length });
});

module.exports = router;
