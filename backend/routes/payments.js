const router = require('express').Router();
const { query, queryOne, run } = require('../db');

function nextReceiptNo() {
  const last = queryOne('SELECT receipt_no FROM payments ORDER BY id DESC LIMIT 1');
  if (!last) return 'RCP-0001';
  const num = parseInt(last.receipt_no.split('-')[1]) + 1;
  return `RCP-${String(num).padStart(4, '0')}`;
}

router.post('/', (req, res) => {
  const { challan_id, student_id, amount_paid, payment_mode, cheque_no, cheque_date, bank_name, collected_by, payment_date, remarks } = req.body;
  const challan = queryOne('SELECT * FROM challans WHERE id=?', [challan_id]);
  if (!challan) return res.status(404).json({ error: 'Challan not found' });

  const paidRow = queryOne('SELECT COALESCE(SUM(amount_paid),0) as paid FROM payments WHERE challan_id=?', [challan_id]);
  const totalPaid = paidRow ? paidRow.paid : 0;
  const remaining = challan.net_amount - totalPaid;
  if (amount_paid > remaining + 0.01) return res.status(400).json({ error: `Amount exceeds due: ${remaining.toFixed(2)}` });

  const receipt_no = nextReceiptNo();
  const r = run(
    `INSERT INTO payments (receipt_no,challan_id,student_id,amount_paid,payment_mode,cheque_no,cheque_date,bank_name,collected_by,payment_date,remarks)
     VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
    [receipt_no, challan_id, student_id, amount_paid, payment_mode,
     cheque_no || null, cheque_date || null, bank_name || null,
     collected_by, payment_date || new Date().toISOString().split('T')[0], remarks || null]
  );

  const newPaid = totalPaid + amount_paid;
  const newStatus = newPaid >= challan.net_amount - 0.01 ? 'paid' : 'partial';
  run('UPDATE challans SET status=? WHERE id=?', [newStatus, challan_id]);

  res.json({ id: r.lastInsertRowid, receipt_no });
});

router.get('/', (req, res) => {
  const { student_id, date, from_date, to_date, payment_mode } = req.query;
  let q = `SELECT p.*, s.name as student_name, s.class, s.section, s.admission_no,
    u.name as collected_by_name, c.challan_no, ft.name as fee_type_name
    FROM payments p
    JOIN students s ON p.student_id=s.id
    JOIN users u ON p.collected_by=u.id
    JOIN challans c ON p.challan_id=c.id
    JOIN fee_structures fs ON c.fee_structure_id=fs.id
    JOIN fee_types ft ON fs.fee_type_id=ft.id WHERE 1=1`;
  const params = [];
  if (student_id) { q += ' AND p.student_id=?'; params.push(student_id); }
  if (date) { q += ' AND p.payment_date=?'; params.push(date); }
  if (from_date) { q += ' AND p.payment_date>=?'; params.push(from_date); }
  if (to_date) { q += ' AND p.payment_date<=?'; params.push(to_date); }
  if (payment_mode) { q += ' AND p.payment_mode=?'; params.push(payment_mode); }
  q += ' ORDER BY p.id DESC';
  res.json(query(q, params));
});

router.get('/:id', (req, res) => {
  const p = queryOne(
    `SELECT p.*, s.name as student_name, s.class, s.section, s.admission_no,
     s.parent_name, u.name as collected_by_name, c.challan_no, c.net_amount,
     ft.name as fee_type_name, fs.period_label
     FROM payments p
     JOIN students s ON p.student_id=s.id
     JOIN users u ON p.collected_by=u.id
     JOIN challans c ON p.challan_id=c.id
     JOIN fee_structures fs ON c.fee_structure_id=fs.id
     JOIN fee_types ft ON fs.fee_type_id=ft.id WHERE p.id=?`,
    [req.params.id]
  );
  if (!p) return res.status(404).json({ error: 'Not found' });
  res.json(p);
});

router.post('/reminders', (req, res) => {
  const { student_id, challan_id, method } = req.body;
  const r = run('INSERT INTO reminder_logs (student_id,challan_id,method) VALUES (?,?,?)',
    [student_id, challan_id, method]);
  res.json({ id: r.lastInsertRowid });
});

module.exports = router;
