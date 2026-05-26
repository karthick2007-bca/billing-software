const router = require('express').Router();
const { query, queryOne, run } = require('../db');

// ─── HELPERS ────────────────────────────────────────────────────────────────
function nextReceiptNo(prefix, table, col) {
  const last = queryOne(`SELECT ${col} FROM ${table} ORDER BY id DESC LIMIT 1`);
  if (!last) return `${prefix}-0001`;
  const parts = last[col].split('-');
  const num = parseInt(parts[parts.length - 1]) + 1;
  return `${prefix}-${String(num).padStart(4, '0')}`;
}

// ═══════════════════════════════════════════════════════════════════════════
// SUB-MODULE 1: STORE / INVENTORY
// ═══════════════════════════════════════════════════════════════════════════

router.get('/store/items', (req, res) => {
  const { search, category, low_stock } = req.query;
  let q = 'SELECT * FROM inv_store_items WHERE active=1';
  const p = [];
  if (search) { q += ' AND (name LIKE ? OR item_code LIKE ?)'; p.push(`%${search}%`, `%${search}%`); }
  if (category) { q += ' AND category=?'; p.push(category); }
  if (low_stock === '1') q += ' AND current_stock <= reorder_level';
  q += ' ORDER BY name';
  res.json(query(q, p));
});

router.get('/store/items/:id', (req, res) => {
  const item = queryOne('SELECT * FROM inv_store_items WHERE id=?', [req.params.id]);
  if (!item) return res.status(404).json({ error: 'Not found' });
  const txns = query('SELECT * FROM inv_store_txn WHERE item_id=? ORDER BY id DESC', [req.params.id]);
  res.json({ ...item, transactions: txns });
});

router.post('/store/items', (req, res) => {
  const { item_code, name, category, unit, opening_stock, reorder_level, supplier_name } = req.body;
  const stock = parseFloat(opening_stock) || 0;
  const r = run(
    `INSERT INTO inv_store_items (item_code,name,category,unit,opening_stock,current_stock,reorder_level,supplier_name)
     VALUES (?,?,?,?,?,?,?,?)`,
    [item_code, name, category, unit || 'nos', stock, stock, parseFloat(reorder_level) || 0, supplier_name || null]
  );
  res.json({ id: r.lastInsertRowid });
});

router.put('/store/items/:id', (req, res) => {
  const { name, category, unit, reorder_level, supplier_name } = req.body;
  run('UPDATE inv_store_items SET name=?,category=?,unit=?,reorder_level=?,supplier_name=? WHERE id=?',
    [name, category, unit, parseFloat(reorder_level) || 0, supplier_name || null, req.params.id]);
  res.json({ success: true });
});

router.delete('/store/items/:id', (req, res) => {
  run('UPDATE inv_store_items SET active=0 WHERE id=?', [req.params.id]);
  res.json({ success: true });
});

router.post('/store/items/:id/stock-in', (req, res) => {
  const { quantity, remarks } = req.body;
  const qty = parseFloat(quantity);
  if (!qty || qty <= 0) return res.status(400).json({ error: 'Invalid quantity' });
  run('UPDATE inv_store_items SET current_stock=current_stock+? WHERE id=?', [qty, req.params.id]);
  run('INSERT INTO inv_store_txn (item_id,txn_type,quantity,remarks) VALUES (?,?,?,?)',
    [req.params.id, 'stock_in', qty, remarks || null]);
  res.json({ success: true });
});

router.post('/store/items/:id/stock-out', (req, res) => {
  const { quantity, remarks } = req.body;
  const qty = parseFloat(quantity);
  if (!qty || qty <= 0) return res.status(400).json({ error: 'Invalid quantity' });
  const item = queryOne('SELECT current_stock FROM inv_store_items WHERE id=?', [req.params.id]);
  if (!item || item.current_stock < qty) return res.status(400).json({ error: 'Insufficient stock' });
  run('UPDATE inv_store_items SET current_stock=current_stock-? WHERE id=?', [qty, req.params.id]);
  run('INSERT INTO inv_store_txn (item_id,txn_type,quantity,remarks) VALUES (?,?,?,?)',
    [req.params.id, 'stock_out', qty, remarks || null]);
  res.json({ success: true });
});

router.get('/store/transactions', (req, res) => {
  const { item_id, from_date, to_date, txn_type } = req.query;
  let q = `SELECT t.*, i.name as item_name, i.item_code, i.unit FROM inv_store_txn t
    JOIN inv_store_items i ON t.item_id=i.id WHERE 1=1`;
  const p = [];
  if (item_id) { q += ' AND t.item_id=?'; p.push(item_id); }
  if (txn_type) { q += ' AND t.txn_type=?'; p.push(txn_type); }
  if (from_date) { q += ' AND t.txn_date>=?'; p.push(from_date); }
  if (to_date) { q += ' AND t.txn_date<=?'; p.push(to_date); }
  q += ' ORDER BY t.id DESC';
  res.json(query(q, p));
});

router.get('/store/report', (req, res) => {
  const items = query('SELECT * FROM inv_store_items WHERE active=1 ORDER BY category, name');
  const low = items.filter(i => i.current_stock <= i.reorder_level);
  res.json({ items, low_stock_count: low.length, low_stock_items: low });
});

// ═══════════════════════════════════════════════════════════════════════════
// SUB-MODULE 2: UNIFORM / SHOP
// ═══════════════════════════════════════════════════════════════════════════

router.get('/uniform/items', (req, res) => {
  const { search, size } = req.query;
  let q = 'SELECT * FROM inv_uniform_items WHERE active=1';
  const p = [];
  if (search) { q += ' AND name LIKE ?'; p.push(`%${search}%`); }
  if (size) { q += ' AND size=?'; p.push(size); }
  q += ' ORDER BY name, size';
  res.json(query(q, p));
});

router.post('/uniform/items', (req, res) => {
  const { name, size, color, price, stock } = req.body;
  const r = run('INSERT INTO inv_uniform_items (name,size,color,price,stock) VALUES (?,?,?,?,?)',
    [name, size, color || null, parseFloat(price) || 0, parseInt(stock) || 0]);
  res.json({ id: r.lastInsertRowid });
});

router.put('/uniform/items/:id', (req, res) => {
  const { name, size, color, price, stock } = req.body;
  run('UPDATE inv_uniform_items SET name=?,size=?,color=?,price=?,stock=? WHERE id=?',
    [name, size, color || null, parseFloat(price) || 0, parseInt(stock) || 0, req.params.id]);
  res.json({ success: true });
});

router.delete('/uniform/items/:id', (req, res) => {
  run('UPDATE inv_uniform_items SET active=0 WHERE id=?', [req.params.id]);
  res.json({ success: true });
});

router.post('/uniform/sales', (req, res) => {
  const { student_id, student_name, items, payment_mode } = req.body;
  if (!items || !items.length) return res.status(400).json({ error: 'No items' });
  let total = 0;
  for (const it of items) {
    const inv = queryOne('SELECT stock, price FROM inv_uniform_items WHERE id=?', [it.item_id]);
    if (!inv || inv.stock < it.quantity) return res.status(400).json({ error: `Insufficient stock for item ${it.item_id}` });
    total += (it.unit_price || inv.price) * it.quantity;
  }
  const receipt_no = nextReceiptNo('USR', 'inv_uniform_sales', 'receipt_no');
  const saleR = run('INSERT INTO inv_uniform_sales (receipt_no,student_id,student_name,total_amount,payment_mode) VALUES (?,?,?,?,?)',
    [receipt_no, student_id || null, student_name || null, total, payment_mode || 'cash']);
  const saleId = saleR.lastInsertRowid;
  for (const it of items) {
    const inv = queryOne('SELECT price FROM inv_uniform_items WHERE id=?', [it.item_id]);
    run('INSERT INTO inv_uniform_sale_items (sale_id,item_id,quantity,unit_price) VALUES (?,?,?,?)',
      [saleId, it.item_id, it.quantity, it.unit_price || inv.price]);
    run('UPDATE inv_uniform_items SET stock=stock-? WHERE id=?', [it.quantity, it.item_id]);
  }
  res.json({ id: saleId, receipt_no, total });
});

router.get('/uniform/sales', (req, res) => {
  const { student_id, from_date, to_date } = req.query;
  let q = 'SELECT * FROM inv_uniform_sales WHERE 1=1';
  const p = [];
  if (student_id) { q += ' AND student_id=?'; p.push(student_id); }
  if (from_date) { q += ' AND sale_date>=?'; p.push(from_date); }
  if (to_date) { q += ' AND sale_date<=?'; p.push(to_date); }
  q += ' ORDER BY id DESC';
  const sales = query(q, p);
  const result = sales.map(s => {
    const saleItems = query(
      `SELECT si.*, ui.name, ui.size, ui.color FROM inv_uniform_sale_items si
       JOIN inv_uniform_items ui ON si.item_id=ui.id WHERE si.sale_id=?`, [s.id]);
    return { ...s, items: saleItems };
  });
  res.json(result);
});

router.get('/uniform/report', (req, res) => {
  const items = query('SELECT * FROM inv_uniform_items WHERE active=1 ORDER BY name, size');
  const salesTotal = queryOne('SELECT COALESCE(SUM(total_amount),0) as total FROM inv_uniform_sales');
  res.json({ items, total_sales: salesTotal?.total || 0 });
});

// ═══════════════════════════════════════════════════════════════════════════
// SUB-MODULE 3: BOOKS / STATIONERY
// ═══════════════════════════════════════════════════════════════════════════

router.get('/books/items', (req, res) => {
  const { search, class_applicable, category } = req.query;
  let q = 'SELECT * FROM inv_book_items WHERE active=1';
  const p = [];
  if (search) { q += ' AND (name LIKE ? OR author LIKE ? OR publisher LIKE ?)'; p.push(`%${search}%`, `%${search}%`, `%${search}%`); }
  if (class_applicable) { q += ' AND class_applicable=?'; p.push(class_applicable); }
  if (category) { q += ' AND category=?'; p.push(category); }
  q += ' ORDER BY class_applicable, name';
  res.json(query(q, p));
});

router.post('/books/items', (req, res) => {
  const { name, author, publisher, class_applicable, category, price, stock } = req.body;
  const r = run('INSERT INTO inv_book_items (name,author,publisher,class_applicable,category,price,stock) VALUES (?,?,?,?,?,?,?)',
    [name, author || null, publisher || null, class_applicable || null, category || 'book', parseFloat(price) || 0, parseInt(stock) || 0]);
  res.json({ id: r.lastInsertRowid });
});

router.put('/books/items/:id', (req, res) => {
  const { name, author, publisher, class_applicable, category, price, stock } = req.body;
  run('UPDATE inv_book_items SET name=?,author=?,publisher=?,class_applicable=?,category=?,price=?,stock=? WHERE id=?',
    [name, author || null, publisher || null, class_applicable || null, category || 'book', parseFloat(price) || 0, parseInt(stock) || 0, req.params.id]);
  res.json({ success: true });
});

router.delete('/books/items/:id', (req, res) => {
  run('UPDATE inv_book_items SET active=0 WHERE id=?', [req.params.id]);
  res.json({ success: true });
});

router.post('/books/sales', (req, res) => {
  const { student_id, student_name, items, payment_mode } = req.body;
  if (!items || !items.length) return res.status(400).json({ error: 'No items' });
  let total = 0;
  for (const it of items) {
    const inv = queryOne('SELECT stock, price FROM inv_book_items WHERE id=?', [it.item_id]);
    if (!inv || inv.stock < it.quantity) return res.status(400).json({ error: `Insufficient stock for item ${it.item_id}` });
    total += (it.unit_price || inv.price) * it.quantity;
  }
  const receipt_no = nextReceiptNo('BSR', 'inv_book_sales', 'receipt_no');
  const saleR = run('INSERT INTO inv_book_sales (receipt_no,student_id,student_name,total_amount,payment_mode) VALUES (?,?,?,?,?)',
    [receipt_no, student_id || null, student_name || null, total, payment_mode || 'cash']);
  const saleId = saleR.lastInsertRowid;
  for (const it of items) {
    const inv = queryOne('SELECT price FROM inv_book_items WHERE id=?', [it.item_id]);
    run('INSERT INTO inv_book_sale_items (sale_id,item_id,quantity,unit_price) VALUES (?,?,?,?)',
      [saleId, it.item_id, it.quantity, it.unit_price || inv.price]);
    run('UPDATE inv_book_items SET stock=stock-? WHERE id=?', [it.quantity, it.item_id]);
  }
  res.json({ id: saleId, receipt_no, total });
});

router.get('/books/sales', (req, res) => {
  const { student_id, from_date, to_date } = req.query;
  let q = 'SELECT * FROM inv_book_sales WHERE 1=1';
  const p = [];
  if (student_id) { q += ' AND student_id=?'; p.push(student_id); }
  if (from_date) { q += ' AND sale_date>=?'; p.push(from_date); }
  if (to_date) { q += ' AND sale_date<=?'; p.push(to_date); }
  q += ' ORDER BY id DESC';
  const sales = query(q, p);
  const result = sales.map(s => {
    const saleItems = query(
      `SELECT si.*, bi.name, bi.author, bi.class_applicable FROM inv_book_sale_items si
       JOIN inv_book_items bi ON si.item_id=bi.id WHERE si.sale_id=?`, [s.id]);
    return { ...s, items: saleItems };
  });
  res.json(result);
});

router.get('/books/report', (req, res) => {
  const items = query('SELECT * FROM inv_book_items WHERE active=1 ORDER BY class_applicable, name');
  const salesTotal = queryOne('SELECT COALESCE(SUM(total_amount),0) as total FROM inv_book_sales');
  res.json({ items, total_sales: salesTotal?.total || 0 });
});

module.exports = router;
