const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');

const DB_PATH = path.join(__dirname, 'school_billing.db');

let db;

async function initDb() {
  const SQL = await initSqlJs();

  if (fs.existsSync(DB_PATH)) {
    const fileBuffer = fs.readFileSync(DB_PATH);
    db = new SQL.Database(fileBuffer);
  } else {
    db = new SQL.Database();
  }

  db.run('PRAGMA foreign_keys = ON;');

  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('admin','accountant','frontdesk')),
      name TEXT NOT NULL,
      active INTEGER DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS academic_years (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      label TEXT UNIQUE NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT NOT NULL,
      is_current INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS students (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      admission_no TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      class TEXT NOT NULL,
      section TEXT NOT NULL,
      roll_no TEXT,
      dob TEXT,
      gender TEXT,
      parent_name TEXT,
      parent_phone TEXT,
      parent_email TEXT,
      address TEXT,
      sibling_group_id INTEGER,
      academic_year_id INTEGER NOT NULL,
      active INTEGER DEFAULT 1,
      FOREIGN KEY(academic_year_id) REFERENCES academic_years(id)
    );

    CREATE TABLE IF NOT EXISTS fee_types (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category TEXT NOT NULL CHECK(category IN ('tuition','transport','library','sports','miscellaneous')),
      academic_year_id INTEGER NOT NULL,
      FOREIGN KEY(academic_year_id) REFERENCES academic_years(id)
    );

    CREATE TABLE IF NOT EXISTS fee_structures (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fee_type_id INTEGER NOT NULL,
      class TEXT NOT NULL,
      section TEXT,
      period_type TEXT NOT NULL CHECK(period_type IN ('monthly','term','annual')),
      period_label TEXT NOT NULL,
      amount REAL NOT NULL,
      due_date TEXT,
      academic_year_id INTEGER NOT NULL,
      FOREIGN KEY(fee_type_id) REFERENCES fee_types(id),
      FOREIGN KEY(academic_year_id) REFERENCES academic_years(id)
    );

    CREATE TABLE IF NOT EXISTS discounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL CHECK(type IN ('percentage','fixed')),
      value REAL NOT NULL,
      scope TEXT NOT NULL CHECK(scope IN ('student','class','sibling','scholarship')),
      academic_year_id INTEGER NOT NULL,
      FOREIGN KEY(academic_year_id) REFERENCES academic_years(id)
    );

    CREATE TABLE IF NOT EXISTS student_discounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL,
      discount_id INTEGER NOT NULL,
      fee_structure_id INTEGER,
      FOREIGN KEY(student_id) REFERENCES students(id),
      FOREIGN KEY(discount_id) REFERENCES discounts(id)
    );

    CREATE TABLE IF NOT EXISTS challans (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      challan_no TEXT UNIQUE NOT NULL,
      student_id INTEGER NOT NULL,
      academic_year_id INTEGER NOT NULL,
      fee_structure_id INTEGER NOT NULL,
      original_amount REAL NOT NULL,
      discount_amount REAL DEFAULT 0,
      net_amount REAL NOT NULL,
      due_date TEXT,
      status TEXT DEFAULT 'pending' CHECK(status IN ('pending','paid','partial','waived')),
      carry_forward INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY(student_id) REFERENCES students(id),
      FOREIGN KEY(academic_year_id) REFERENCES academic_years(id),
      FOREIGN KEY(fee_structure_id) REFERENCES fee_structures(id)
    );

    CREATE TABLE IF NOT EXISTS payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receipt_no TEXT UNIQUE NOT NULL,
      challan_id INTEGER NOT NULL,
      student_id INTEGER NOT NULL,
      amount_paid REAL NOT NULL,
      payment_mode TEXT NOT NULL CHECK(payment_mode IN ('cash','cheque')),
      cheque_no TEXT,
      cheque_date TEXT,
      bank_name TEXT,
      collected_by INTEGER NOT NULL,
      payment_date TEXT DEFAULT (date('now')),
      remarks TEXT,
      FOREIGN KEY(challan_id) REFERENCES challans(id),
      FOREIGN KEY(student_id) REFERENCES students(id),
      FOREIGN KEY(collected_by) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS reminder_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL,
      challan_id INTEGER NOT NULL,
      method TEXT NOT NULL CHECK(method IN ('sms','print')),
      sent_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY(student_id) REFERENCES students(id),
      FOREIGN KEY(challan_id) REFERENCES challans(id)
    );

    CREATE TABLE IF NOT EXISTS inv_store_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_code TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      unit TEXT NOT NULL DEFAULT 'nos',
      opening_stock REAL NOT NULL DEFAULT 0,
      current_stock REAL NOT NULL DEFAULT 0,
      reorder_level REAL NOT NULL DEFAULT 0,
      supplier_name TEXT,
      active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS inv_store_txn (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      txn_type TEXT NOT NULL CHECK(txn_type IN ('stock_in','stock_out')),
      quantity REAL NOT NULL,
      remarks TEXT,
      txn_date TEXT DEFAULT (date('now')),
      created_by INTEGER,
      FOREIGN KEY(item_id) REFERENCES inv_store_items(id)
    );

    CREATE TABLE IF NOT EXISTS inv_uniform_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      size TEXT NOT NULL,
      color TEXT,
      price REAL NOT NULL DEFAULT 0,
      stock INTEGER NOT NULL DEFAULT 0,
      active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS inv_uniform_sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receipt_no TEXT UNIQUE NOT NULL,
      student_id INTEGER,
      student_name TEXT,
      sale_date TEXT DEFAULT (date('now')),
      total_amount REAL NOT NULL DEFAULT 0,
      payment_mode TEXT DEFAULT 'cash',
      created_by INTEGER
    );

    CREATE TABLE IF NOT EXISTS inv_uniform_sale_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL,
      item_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price REAL NOT NULL,
      FOREIGN KEY(sale_id) REFERENCES inv_uniform_sales(id),
      FOREIGN KEY(item_id) REFERENCES inv_uniform_items(id)
    );

    CREATE TABLE IF NOT EXISTS inv_book_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      author TEXT,
      publisher TEXT,
      class_applicable TEXT,
      category TEXT NOT NULL DEFAULT 'book',
      price REAL NOT NULL DEFAULT 0,
      stock INTEGER NOT NULL DEFAULT 0,
      active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS inv_book_sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      receipt_no TEXT UNIQUE NOT NULL,
      student_id INTEGER,
      student_name TEXT,
      sale_date TEXT DEFAULT (date('now')),
      total_amount REAL NOT NULL DEFAULT 0,
      payment_mode TEXT DEFAULT 'cash',
      created_by INTEGER
    );

    CREATE TABLE IF NOT EXISTS inv_book_sale_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL,
      item_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price REAL NOT NULL,
      FOREIGN KEY(sale_id) REFERENCES inv_book_sales(id),
      FOREIGN KEY(item_id) REFERENCES inv_book_items(id)
    );
  `);

  // Seed default admin
  const existing = queryOne('SELECT id FROM users WHERE username = ?', ['admin']);
  if (!existing) {
    const hash = bcrypt.hashSync('admin123', 10);
    run('INSERT INTO users (username,password,role,name) VALUES (?,?,?,?)', ['admin', hash, 'admin', 'Administrator']);
  }

  persist();
  return db;
}

function persist() {
  const data = db.export();
  fs.writeFileSync(DB_PATH, Buffer.from(data));
}

function run(sql, params = []) {
  db.run(sql, params);
  persist();
  // Get last insert rowid
  const result = queryOne('SELECT last_insert_rowid() as id', []);
  return { lastInsertRowid: result ? result.id : null };
}

function query(sql, params = []) {
  const stmt = db.prepare(sql);
  stmt.bind(params);
  const rows = [];
  while (stmt.step()) {
    rows.push(stmt.getAsObject());
  }
  stmt.free();
  return rows;
}

function queryOne(sql, params = []) {
  const rows = query(sql, params);
  return rows.length > 0 ? rows[0] : null;
}

module.exports = { initDb, run, query, queryOne, persist };
