const router = require('express').Router();
const { query, queryOne } = require('../db');

router.get('/daily-collection', (req, res) => {
  const d = req.query.date || new Date().toISOString().split('T')[0];
  const payments = query(
    `SELECT p.*, s.name as student_name, s.class, s.section, s.admission_no,
     ft.name as fee_type_name, u.name as collected_by_name
     FROM payments p JOIN students s ON p.student_id=s.id
     JOIN challans c ON p.challan_id=c.id
     JOIN fee_structures fs ON c.fee_structure_id=fs.id
     JOIN fee_types ft ON fs.fee_type_id=ft.id
     JOIN users u ON p.collected_by=u.id
     WHERE p.payment_date=? ORDER BY p.id`,
    [d]
  );
  const total = payments.reduce((s, p) => s + p.amount_paid, 0);
  const cash = payments.filter(p => p.payment_mode === 'cash').reduce((s, p) => s + p.amount_paid, 0);
  const cheque = payments.filter(p => p.payment_mode === 'cheque').reduce((s, p) => s + p.amount_paid, 0);
  res.json({ date: d, payments, total, cash, cheque });
});

router.get('/defaulters', (req, res) => {
  const { academic_year_id, class: cls, section } = req.query;
  let q = `SELECT s.id, s.admission_no, s.name, s.class, s.section, s.parent_name, s.parent_phone,
    SUM(c.net_amount) as total_due
    FROM challans c JOIN students s ON c.student_id=s.id
    WHERE c.academic_year_id=? AND c.status IN ('pending','partial')`;
  const params = [academic_year_id];
  if (cls) { q += ' AND s.class=?'; params.push(cls); }
  if (section) { q += ' AND s.section=?'; params.push(section); }
  q += ' GROUP BY s.id ORDER BY s.class, s.section, s.name';
  const rows = query(q, params);

  const result = rows.map(r => {
    const paidRow = queryOne(
      `SELECT COALESCE(SUM(p.amount_paid),0) as paid FROM payments p
       JOIN challans c ON p.challan_id=c.id
       WHERE c.student_id=? AND c.academic_year_id=?`,
      [r.id, academic_year_id]
    );
    const total_paid = paidRow ? paidRow.paid : 0;
    return { ...r, total_paid, balance: r.total_due - total_paid };
  });
  res.json(result);
});

router.get('/class-summary', (req, res) => {
  const { academic_year_id } = req.query;
  const rows = query(
    `SELECT s.class, s.section,
     COUNT(DISTINCT s.id) as student_count,
     SUM(c.net_amount) as total_billed
     FROM challans c JOIN students s ON c.student_id=s.id
     WHERE c.academic_year_id=?
     GROUP BY s.class, s.section ORDER BY s.class, s.section`,
    [academic_year_id]
  );
  const result = rows.map(r => {
    const paidRow = queryOne(
      `SELECT COALESCE(SUM(p.amount_paid),0) as collected FROM payments p
       JOIN challans c ON p.challan_id=c.id
       JOIN students s ON c.student_id=s.id
       WHERE c.academic_year_id=? AND s.class=? AND s.section=?`,
      [academic_year_id, r.class, r.section]
    );
    const total_collected = paidRow ? paidRow.collected : 0;
    return { ...r, total_collected, pending: r.total_billed - total_collected };
  });
  res.json(result);
});

router.get('/annual-income', (req, res) => {
  const { academic_year_id } = req.query;
  const rows = query(
    `SELECT ft.name as fee_type, ft.category, SUM(c.net_amount) as total_billed
     FROM challans c
     JOIN fee_structures fs ON c.fee_structure_id=fs.id
     JOIN fee_types ft ON fs.fee_type_id=ft.id
     WHERE c.academic_year_id=?
     GROUP BY ft.id ORDER BY ft.category`,
    [academic_year_id]
  );
  const result = rows.map(r => {
    const paidRow = queryOne(
      `SELECT COALESCE(SUM(p.amount_paid),0) as collected FROM payments p
       JOIN challans c ON p.challan_id=c.id
       JOIN fee_structures fs ON c.fee_structure_id=fs.id
       JOIN fee_types ft ON fs.fee_type_id=ft.id
       WHERE c.academic_year_id=? AND ft.name=?`,
      [academic_year_id, r.fee_type]
    );
    return { ...r, total_collected: paidRow ? paidRow.collected : 0 };
  });
  const grand_total_billed = result.reduce((s, r) => s + r.total_billed, 0);
  const grand_total_collected = result.reduce((s, r) => s + r.total_collected, 0);
  res.json({ rows: result, grand_total_billed, grand_total_collected, pending: grand_total_billed - grand_total_collected });
});

router.get('/category-breakdown', (req, res) => {
  const { academic_year_id, from_date, to_date } = req.query;
  let q = `SELECT ft.category, SUM(p.amount_paid) as collected
    FROM payments p JOIN challans c ON p.challan_id=c.id
    JOIN fee_structures fs ON c.fee_structure_id=fs.id
    JOIN fee_types ft ON fs.fee_type_id=ft.id
    WHERE c.academic_year_id=?`;
  const params = [academic_year_id];
  if (from_date) { q += ' AND p.payment_date>=?'; params.push(from_date); }
  if (to_date) { q += ' AND p.payment_date<=?'; params.push(to_date); }
  q += ' GROUP BY ft.category';
  res.json(query(q, params));
});

module.exports = router;
