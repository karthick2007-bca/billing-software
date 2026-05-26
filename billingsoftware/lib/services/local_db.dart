import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

class LocalDb {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    // Windows/Linux/macOS desktop needs FFI
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'school_billing.db');
    return openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''CREATE TABLE academic_years (
        id INTEGER PRIMARY KEY AUTOINCREMENT, label TEXT NOT NULL,
        start_date TEXT, end_date TEXT, is_current INTEGER DEFAULT 0)''');

      await db.execute('''CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, username TEXT UNIQUE,
        password TEXT, role TEXT, active INTEGER DEFAULT 1)''');

      await db.execute('''CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT, admission_no TEXT, name TEXT NOT NULL,
        class TEXT, section TEXT, roll_no TEXT, dob TEXT, gender TEXT,
        parent_name TEXT, parent_phone TEXT, parent_email TEXT, address TEXT,
        sibling_group_id TEXT, academic_year_id INTEGER, active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');

      await db.execute('''CREATE TABLE fee_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
        category TEXT, academic_year_id INTEGER)''');

      await db.execute('''CREATE TABLE fee_structures (
        id INTEGER PRIMARY KEY AUTOINCREMENT, fee_type_id INTEGER,
        class TEXT, section TEXT, period_type TEXT, period_label TEXT,
        amount REAL, due_date TEXT, academic_year_id INTEGER)''');

      await db.execute('''CREATE TABLE discounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, type TEXT,
        value REAL, scope TEXT, academic_year_id INTEGER)''');

      await db.execute('''CREATE TABLE student_discounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER, discount_id INTEGER, discount_name TEXT,
        discount_type TEXT, discount_value REAL, discount_scope TEXT)''');

      await db.execute('''CREATE TABLE challans (
        id INTEGER PRIMARY KEY AUTOINCREMENT, challan_no TEXT,
        student_id INTEGER, fee_type_id INTEGER, fee_type_name TEXT,
        period_label TEXT, gross_amount REAL, discount_amount REAL DEFAULT 0,
        net_amount REAL, status TEXT DEFAULT 'pending', due_date TEXT,
        academic_year_id INTEGER, created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');

      await db.execute('''CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT, receipt_no TEXT,
        challan_id INTEGER, student_id INTEGER, fee_type_name TEXT,
        amount_paid REAL, payment_mode TEXT, cheque_no TEXT,
        cheque_date TEXT, bank_name TEXT,
        payment_date TEXT DEFAULT CURRENT_DATE,
        collected_by INTEGER, collected_by_name TEXT, remarks TEXT)''');

      await db.execute('''CREATE TABLE shop_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
        size TEXT, color TEXT, category TEXT, price REAL,
        stock INTEGER DEFAULT 0, created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');

      await db.execute('''CREATE TABLE book_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
        author TEXT, publisher TEXT, class_applicable TEXT,
        category TEXT, price REAL, stock INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');

      await db.execute('''CREATE TABLE IF NOT EXISTS inventory_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_no TEXT NOT NULL,
        student_id INTEGER,
        student_name TEXT,
        student_class TEXT,
        student_section TEXT,
        admission_no TEXT,
        sale_date TEXT,
        subtotal REAL,
        discount_amount REAL DEFAULT 0,
        grand_total REAL,
        payment_mode TEXT,
        cheque_no TEXT,
        bank_name TEXT,
        remarks TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )''');

      await db.execute('''CREATE TABLE IF NOT EXISTS inventory_sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        item_type TEXT,
        item_id INTEGER,
        item_name TEXT,
        size TEXT,
        quantity INTEGER,
        unit_price REAL,
        total_price REAL
      )''');

      // Default data
      await db.insert('users', {'name': 'Administrator', 'username': 'admin', 'password': 'admin123', 'role': 'admin', 'active': 1});
      await db.insert('academic_years', {'label': '2024-25', 'start_date': '2024-06-01', 'end_date': '2025-03-31', 'is_current': 1});
    });
  }

  // ── Academic Years ──
  static Future<List<Map>> getAcademicYears() async => (await db).query('academic_years', orderBy: 'id DESC');

  static Future<int> insertAcademicYear(Map<String, dynamic> data) async => (await db).insert('academic_years', data);

  static Future<void> setCurrentYear(int id) async {
    final d = await db;
    await d.update('academic_years', {'is_current': 0});
    await d.update('academic_years', {'is_current': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // ── Users ──
  static Future<Map?> loginUser(String username, String password) async {
    final r = await (await db).query('users', where: 'username = ? AND password = ? AND active = 1', whereArgs: [username, password]);
    return r.isNotEmpty ? r.first : null;
  }

  static Future<List<Map>> getUsers() async => (await db).query('users');

  static Future<int> insertUser(Map<String, dynamic> data) async => (await db).insert('users', data);

  static Future<void> updateUser(int id, Map<String, dynamic> data) async =>
      (await db).update('users', data, where: 'id = ?', whereArgs: [id]);

  // ── Students with balance ──
  static Future<List<Map>> getStudentsWithBalance({String? search, String? classFilter, int? yearId}) async {
    final d = await db;
    String where = 's.active = 1';
    List args = [];
    if (yearId != null) { where += ' AND s.academic_year_id = ?'; args.add(yearId); }
    if (classFilter != null && classFilter.isNotEmpty) { where += ' AND s.class = ?'; args.add(classFilter); }
    if (search != null && search.isNotEmpty) {
      where += ' AND (s.name LIKE ? OR s.admission_no LIKE ? OR s.roll_no LIKE ?)';
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }
    return d.rawQuery('''
      SELECT s.*,
        COALESCE(SUM(c.net_amount), 0) as total_billed,
        COALESCE(SUM(CASE WHEN c.status = 'paid' THEN c.net_amount ELSE 0 END), 0) as total_paid,
        COALESCE(SUM(CASE WHEN c.status IN ('pending','partial') THEN c.net_amount ELSE 0 END), 0) as balance,
        CASE
          WHEN COUNT(c.id) = 0 THEN 'no_challan'
          WHEN SUM(CASE WHEN c.status IN ('pending','partial') THEN 1 ELSE 0 END) = 0 THEN 'paid'
          ELSE 'pending'
        END as fee_status
      FROM students s
      LEFT JOIN challans c ON s.id = c.student_id
        AND c.academic_year_id = s.academic_year_id
      WHERE $where
      GROUP BY s.id
      ORDER BY s.class, s.section, s.roll_no
    ''', args);
  }

  // ── Students ──
  static Future<List<Map>> getStudents({String? search, String? classFilter, int? yearId}) async {
    final d = await db;
    String where = 'active = 1';
    List args = [];
    if (yearId != null) { where += ' AND academic_year_id = ?'; args.add(yearId); }
    if (classFilter != null && classFilter.isNotEmpty) { where += ' AND class = ?'; args.add(classFilter); }
    if (search != null && search.isNotEmpty) { where += ' AND (name LIKE ? OR admission_no LIKE ?)'; args.addAll(['%$search%', '%$search%']); }
    return d.query('students', where: where, whereArgs: args, orderBy: 'name');
  }

  static Future<Map?> getStudent(int id) async {
    final r = await (await db).query('students', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
  }

  static Future<int> insertStudent(Map<String, dynamic> data) async => (await db).insert('students', data);

  static Future<void> updateStudent(int id, Map<String, dynamic> data) async =>
      (await db).update('students', data, where: 'id = ?', whereArgs: [id]);

  // ── Fee Types ──
  static Future<List<Map>> getFeeTypes(int yearId) async =>
      (await db).query('fee_types', where: 'academic_year_id = ?', whereArgs: [yearId]);

  static Future<int> insertFeeType(Map<String, dynamic> data) async => (await db).insert('fee_types', data);

  static Future<void> deleteFeeType(int id) async =>
      (await db).delete('fee_types', where: 'id = ?', whereArgs: [id]);

  // ── Fee Structures ──
  static Future<List<Map>> getFeeStructures(int yearId) async =>
      (await db).rawQuery('''SELECT fs.*, ft.name as fee_type_name, ft.category as fee_category FROM fee_structures fs
        LEFT JOIN fee_types ft ON fs.fee_type_id = ft.id
        WHERE fs.academic_year_id = ?''', [yearId]);

  static Future<int> insertFeeStructure(Map<String, dynamic> data) async => (await db).insert('fee_structures', data);

  static Future<void> updateFeeStructure(int id, double amount) async =>
      (await db).update('fee_structures', {'amount': amount}, where: 'id = ?', whereArgs: [id]);

  static Future<void> deleteFeeStructure(int id) async =>
      (await db).delete('fee_structures', where: 'id = ?', whereArgs: [id]);

  // ── Discounts ──
  static Future<List<Map>> getDiscounts(int yearId) async =>
      (await db).query('discounts', where: 'academic_year_id = ?', whereArgs: [yearId]);

  static Future<int> insertDiscount(Map<String, dynamic> data) async => (await db).insert('discounts', data);

  static Future<void> deleteDiscount(int id) async =>
      (await db).delete('discounts', where: 'id = ?', whereArgs: [id]);

  // ── Student Discounts ──
  static Future<List<Map>> getStudentDiscounts(int studentId) async =>
      (await db).query('student_discounts', where: 'student_id = ?', whereArgs: [studentId]);

  static Future<void> applyStudentDiscount(int studentId, int discountId) async {
    final d = await db;
    final disc = await d.query('discounts', where: 'id = ?', whereArgs: [discountId]);
    if (disc.isEmpty) return;
    final dd = disc.first;
    await d.insert('student_discounts', {
      'student_id': studentId, 'discount_id': discountId,
      'discount_name': dd['name'], 'discount_type': dd['type'],
      'discount_value': dd['value'], 'discount_scope': dd['scope'],
    });
  }

  static Future<void> removeStudentDiscount(int id) async =>
      (await db).delete('student_discounts', where: 'id = ?', whereArgs: [id]);

  // ── Challan with Student details (for PDF) ──
  static Future<Map<String, dynamic>?> getChallanWithStudent(int challanId) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT c.*, s.name as student_name, s.admission_no, s.class, s.section,
        s.roll_no, s.parent_name, s.parent_phone
      FROM challans c
      LEFT JOIN students s ON c.student_id = s.id
      WHERE c.id = ?
    ''', [challanId]);
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }

  // ── Pending students count ──
  static Future<int> getPendingStudentsCount(int yearId) async {
    final d = await db;
    final r = await d.rawQuery('''
      SELECT COUNT(DISTINCT student_id) as cnt
      FROM challans
      WHERE academic_year_id = ? AND (status = 'pending' OR status = 'partial')
    ''', [yearId]);
    return (r.first['cnt'] as int?) ?? 0;
  }

  // ── Challans ──
  static Future<List<Map>> getChallans({int? studentId, int? yearId, String? status}) async {
    final d = await db;
    String where = '1=1';
    List args = [];
    if (studentId != null) { where += ' AND c.student_id = ?'; args.add(studentId); }
    if (yearId != null) { where += ' AND c.academic_year_id = ?'; args.add(yearId); }
    if (status != null && status.isNotEmpty) { where += ' AND c.status = ?'; args.add(status); }
    return d.rawQuery('''SELECT c.*, s.name as student_name, s.class, s.section,
      s.admission_no, s.parent_name, s.parent_phone,
      ft.category as fee_category
      FROM challans c
      LEFT JOIN students s ON c.student_id = s.id
      LEFT JOIN fee_types ft ON c.fee_type_id = ft.id
      WHERE $where ORDER BY c.created_at DESC''', args);
  }

  static Future<int> generateChallansWithLocationStop(int studentId, int yearId, String locationName, String stopName) async {
    final d = await db;
    final student = await getStudent(studentId);
    if (student == null) return 0;
    int count = 0;

    // Non-transport structures
    final nonTransport = await d.rawQuery('''
      SELECT fs.*, ft.category as fee_category
      FROM fee_structures fs
      LEFT JOIN fee_types ft ON fs.fee_type_id = ft.id
      WHERE fs.academic_year_id = ?
        AND (fs.class = ? OR fs.class IS NULL)
        AND LOWER(COALESCE(ft.category, '')) != 'transport'
    ''', [yearId, student['class']]);
    for (final s in nonTransport) {
      final existing = await d.query('challans',
          where: 'student_id = ? AND fee_type_id = ? AND period_label = ? AND academic_year_id = ?',
          whereArgs: [studentId, s['fee_type_id'], s['period_label'] ?? '', yearId]);
      if (existing.isNotEmpty) continue;
      final feeType = await d.query('fee_types', where: 'id = ?', whereArgs: [s['fee_type_id']]);
      final challanNo = 'CH${DateTime.now().millisecondsSinceEpoch}$count';
      await Future.delayed(const Duration(milliseconds: 1));
      await d.insert('challans', {
        'challan_no': challanNo, 'student_id': studentId,
        'fee_type_id': s['fee_type_id'],
        'fee_type_name': feeType.isNotEmpty ? feeType.first['name'] : '',
        'period_label': s['period_label'] ?? '', 'gross_amount': s['amount'],
        'discount_amount': 0, 'net_amount': s['amount'],
        'status': 'pending', 'due_date': s['due_date'],
        'academic_year_id': yearId,
      });
      count++;
    }

    // Transport structures matching location + stop
    final transportStructures = await d.rawQuery('''
      SELECT fs.*, ft.name as fee_type_name
      FROM fee_structures fs
      LEFT JOIN fee_types ft ON fs.fee_type_id = ft.id
      WHERE fs.academic_year_id = ?
        AND LOWER(COALESCE(ft.category, '')) = 'transport'
        AND fs.class = ?
        AND fs.section = ?
    ''', [yearId, locationName, stopName]);
    for (final s in transportStructures) {
      final existing = await d.query('challans',
          where: 'student_id = ? AND fee_type_id = ? AND period_label = ? AND academic_year_id = ?',
          whereArgs: [studentId, s['fee_type_id'], s['period_label'] ?? '', yearId]);
      if (existing.isNotEmpty) continue;
      final challanNo = 'CH${DateTime.now().millisecondsSinceEpoch}$count';
      await Future.delayed(const Duration(milliseconds: 1));
      await d.insert('challans', {
        'challan_no': challanNo, 'student_id': studentId,
        'fee_type_id': s['fee_type_id'],
        'fee_type_name': s['fee_type_name'] ?? '',
        'period_label': s['period_label'] ?? '', 'gross_amount': s['amount'],
        'discount_amount': 0, 'net_amount': s['amount'],
        'status': 'pending', 'due_date': null,
        'academic_year_id': yearId,
      });
      count++;
    }
    return count;
  }

  static Future<int> generateChallansWithStop(int studentId, int yearId, int stopId) async {
    final d = await db;
    final student = await getStudent(studentId);
    if (student == null) return 0;
    int count = 0;

    // 1. Non-transport structures (class match or class IS NULL but not transport)
    final nonTransport = await d.rawQuery('''
      SELECT fs.*, ft.category as fee_category
      FROM fee_structures fs
      LEFT JOIN fee_types ft ON fs.fee_type_id = ft.id
      WHERE fs.academic_year_id = ?
        AND (fs.class = ? OR fs.class IS NULL)
        AND LOWER(COALESCE(ft.category, '')) != 'transport'
    ''', [yearId, student['class']]);
    for (final s in nonTransport) {
      final existing = await d.query('challans',
          where: 'student_id = ? AND fee_type_id = ? AND period_label = ? AND academic_year_id = ?',
          whereArgs: [studentId, s['fee_type_id'], s['period_label'] ?? '', yearId]);
      if (existing.isNotEmpty) continue;
      final feeType = await d.query('fee_types', where: 'id = ?', whereArgs: [s['fee_type_id']]);
      final challanNo = 'CH${DateTime.now().millisecondsSinceEpoch}$count';
      await Future.delayed(const Duration(milliseconds: 1));
      await d.insert('challans', {
        'challan_no': challanNo, 'student_id': studentId,
        'fee_type_id': s['fee_type_id'],
        'fee_type_name': feeType.isNotEmpty ? feeType.first['name'] : '',
        'period_label': s['period_label'] ?? '', 'gross_amount': s['amount'],
        'discount_amount': 0, 'net_amount': s['amount'],
        'status': 'pending', 'due_date': s['due_date'],
        'academic_year_id': yearId,
      });
      count++;
    }

    // 2. Transport: use stop's term amounts
    final termAmounts = await getStopTermAmounts(stopId);
    final stopRows = await d.query('transport_stops', where: 'id = ?', whereArgs: [stopId]);
    if (stopRows.isEmpty) return count;
    final stopName = stopRows.first['stop_name'] as String;

    // Get transport fee types for this year
    final transportTypes = await d.rawQuery('''
      SELECT ft.* FROM fee_types ft
      WHERE ft.academic_year_id = ? AND LOWER(ft.category) = 'transport'
    ''', [yearId]);
    if (transportTypes.isEmpty) return count;
    final ft = transportTypes.first;

    for (final term in termAmounts) {
      final periodLabel = '${term['period_label']} - $stopName';
      final existing = await d.query('challans',
          where: 'student_id = ? AND fee_type_id = ? AND period_label = ? AND academic_year_id = ?',
          whereArgs: [studentId, ft['id'], periodLabel, yearId]);
      if (existing.isNotEmpty) continue;
      final amt = (term['amount'] as num).toDouble();
      if (amt <= 0) continue;
      final challanNo = 'CH${DateTime.now().millisecondsSinceEpoch}$count';
      await Future.delayed(const Duration(milliseconds: 1));
      await d.insert('challans', {
        'challan_no': challanNo, 'student_id': studentId,
        'fee_type_id': ft['id'],
        'fee_type_name': ft['name'],
        'period_label': periodLabel, 'gross_amount': amt,
        'discount_amount': 0, 'net_amount': amt,
        'status': 'pending', 'due_date': null,
        'academic_year_id': yearId,
      });
      count++;
    }
    return count;
  }

  static Future<int> generateChallans(int studentId, int yearId) async {
    final d = await db;
    final student = await getStudent(studentId);
    if (student == null) return 0;
    // Get structures matching student's class OR class is null (transport/global)
    final structures = await d.rawQuery('''
      SELECT fs.*, ft.category as fee_category
      FROM fee_structures fs
      LEFT JOIN fee_types ft ON fs.fee_type_id = ft.id
      WHERE fs.academic_year_id = ? AND (fs.class = ? OR fs.class IS NULL)
    ''', [yearId, student['class']]);
    int count = 0;
    for (final s in structures) {
      final existing = await d.query('challans',
          where: 'student_id = ? AND fee_type_id = ? AND period_label = ? AND academic_year_id = ?',
          whereArgs: [studentId, s['fee_type_id'], s['period_label'] ?? '', yearId]);
      if (existing.isNotEmpty) continue;
      final feeType = await d.query('fee_types', where: 'id = ?', whereArgs: [s['fee_type_id']]);
      final challanNo = 'CH${DateTime.now().millisecondsSinceEpoch}$count';
      await Future.delayed(const Duration(milliseconds: 1)); // ensure unique challan_no
      await d.insert('challans', {
        'challan_no': challanNo, 'student_id': studentId,
        'fee_type_id': s['fee_type_id'],
        'fee_type_name': feeType.isNotEmpty ? feeType.first['name'] : '',
        'period_label': s['period_label'] ?? '', 'gross_amount': s['amount'],
        'discount_amount': 0, 'net_amount': s['amount'],
        'status': 'pending', 'due_date': s['due_date'],
        'academic_year_id': yearId,
      });
      count++;
    }
    return count;
  }

  static Future<int> generateChallansForPeriods(int studentId, int yearId, List<String> periods) async {
    final d = await db;
    final student = await getStudent(studentId);
    if (student == null) return 0;
    int count = 0;
    final structures = await d.rawQuery('''
      SELECT fs.*, ft.name as fee_type_name, ft.category as fee_category
      FROM fee_structures fs
      LEFT JOIN fee_types ft ON fs.fee_type_id = ft.id
      WHERE fs.academic_year_id = ?
        AND (fs.class = ? OR fs.class IS NULL)
        AND LOWER(COALESCE(ft.category, '')) != 'transport'
    ''', [yearId, student['class']]);
    for (final s in structures) {
      final period = s['period_label'] as String? ?? '';
      if (!periods.contains(period)) continue;
      final existing = await d.query('challans',
          where: 'student_id = ? AND fee_type_id = ? AND period_label = ? AND academic_year_id = ?',
          whereArgs: [studentId, s['fee_type_id'], period, yearId]);
      if (existing.isNotEmpty) continue;
      final challanNo = 'CH${DateTime.now().millisecondsSinceEpoch}$count';
      await Future.delayed(const Duration(milliseconds: 1));
      await d.insert('challans', {
        'challan_no': challanNo, 'student_id': studentId,
        'fee_type_id': s['fee_type_id'],
        'fee_type_name': s['fee_type_name'] ?? '',
        'period_label': period,
        'gross_amount': s['amount'],
        'discount_amount': 0,
        'net_amount': s['amount'],
        'status': 'pending', 'due_date': s['due_date'],
        'academic_year_id': yearId,
      });
      count++;
    }
    return count;
  }

  static Future<void> deleteAllChallans() async =>
      (await db).delete('challans');

  static Future<void> waiveChallan(int id) async =>
      (await db).update('challans', {'status': 'waived'}, where: 'id = ?', whereArgs: [id]);

  static Future<void> deleteChallan(int id) async =>
      (await db).delete('challans', where: 'id = ?', whereArgs: [id]);

  static Future<void> unwaiveChallan(int id) async =>
      (await db).update('challans', {'status': 'pending'}, where: 'id = ?', whereArgs: [id]);

  static Future<void> updateChallanStatus(int id, String status) async =>
      (await db).update('challans', {'status': status}, where: 'id = ?', whereArgs: [id]);

  // ── Payments ──
  static Future<List<Map>> getPayments({int? studentId}) async {
    final d = await db;
    String where = '1=1';
    List args = [];
    if (studentId != null) { where += ' AND p.student_id = ?'; args.add(studentId); }
    return d.rawQuery('''SELECT p.*, s.name as student_name
      FROM payments p LEFT JOIN students s ON p.student_id = s.id
      WHERE $where ORDER BY p.payment_date DESC''', args);
  }

  static Future<Map?> getPayment(int id) async {
    final r = await (await db).rawQuery('''SELECT p.*, s.name as student_name
      FROM payments p LEFT JOIN students s ON p.student_id = s.id
      WHERE p.id = ?''', [id]);
    return r.isNotEmpty ? r.first : null;
  }

  static Future<int> insertPayment(Map<String, dynamic> data) async {
    final d = await db;
    final receiptNo = 'RCP${DateTime.now().millisecondsSinceEpoch}';
    data['receipt_no'] = receiptNo;
    final id = await d.insert('payments', data);
    if (data['challan_id'] != null) {
      final challan = await d.query('challans', where: 'id = ?', whereArgs: [data['challan_id']]);
      if (challan.isNotEmpty) {
        final net = (challan.first['net_amount'] as num).toDouble();
        final paid = (data['amount_paid'] as num).toDouble();
        await updateChallanStatus(data['challan_id'], paid >= net ? 'paid' : 'partial');
      }
    }
    return id;
  }

  // ── Daily Collection ──
  static Future<Map<String, dynamic>> getDailyCollection(String date) async {
    final d = await db;
    final payments = await d.rawQuery('''SELECT p.*, s.name as student_name,
      s.class, s.section FROM payments p
      LEFT JOIN students s ON p.student_id = s.id
      WHERE p.payment_date = ?''', [date]);
    double total = 0, cash = 0, cheque = 0;
    for (final p in payments) {
      final amt = (p['amount_paid'] as num).toDouble();
      total += amt;
      if (p['payment_mode'] == 'cash') cash += amt; else cheque += amt;
    }
    return {'payments': payments, 'total': total, 'cash': cash, 'cheque': cheque};
  }

  // ── Reports ──
  static Future<List<Map>> getClassSummary(int yearId) async {
    final d = await db;
    return d.rawQuery('''SELECT s.class, s.section,
      COUNT(DISTINCT s.id) as student_count,
      COALESCE(SUM(c.net_amount), 0) as total_billed,
      COALESCE(SUM(CASE WHEN c.status='paid' THEN c.net_amount ELSE 0 END), 0) as total_collected,
      COALESCE(SUM(CASE WHEN c.status='pending' OR c.status='partial' THEN c.net_amount ELSE 0 END), 0) as pending
      FROM students s LEFT JOIN challans c ON s.id = c.student_id AND c.academic_year_id = ?
      WHERE s.academic_year_id = ? AND s.active = 1
      GROUP BY s.class, s.section ORDER BY s.class''', [yearId, yearId]);
  }

  static Future<Map<String, dynamic>> getAnnualIncome(int yearId) async {
    final d = await db;
    final rows = await d.rawQuery('''SELECT ft.name as fee_type, ft.category,
      COALESCE(SUM(c.net_amount), 0) as total_billed,
      COALESCE(SUM(CASE WHEN c.status='paid' THEN c.net_amount ELSE 0 END), 0) as total_collected
      FROM fee_types ft LEFT JOIN challans c ON ft.id = c.fee_type_id AND c.academic_year_id = ?
      WHERE ft.academic_year_id = ? GROUP BY ft.id''', [yearId, yearId]);
    double billed = 0, collected = 0;
    for (final r in rows) { billed += (r['total_billed'] as num).toDouble(); collected += (r['total_collected'] as num).toDouble(); }
    // Use actual payments sum for collected
    final payRows = await d.rawQuery('''
      SELECT COALESCE(SUM(p.amount_paid), 0) as total_paid
      FROM payments p
      INNER JOIN challans c ON p.challan_id = c.id
      WHERE c.academic_year_id = ?
    ''', [yearId]);
    final actualCollected = (payRows.first['total_paid'] as num).toDouble();
    return {'rows': rows, 'grand_total_billed': billed, 'grand_total_collected': actualCollected, 'pending': billed - actualCollected};
  }

  static Future<List<Map>> getDefaulters(int yearId, {String? classFilter}) async {
    final d = await db;
    String where = 's.academic_year_id = ? AND s.active = 1';
    List args = [yearId];
    if (classFilter != null && classFilter.isNotEmpty) { where += ' AND s.class = ?'; args.add(classFilter); }
    return d.rawQuery('''SELECT s.id, s.admission_no, s.name, s.class, s.section,
      s.parent_name, s.parent_phone,
      COALESCE(SUM(c.net_amount), 0) as total_due,
      COALESCE(SUM(p.amount_paid), 0) as total_paid,
      COALESCE(SUM(c.net_amount), 0) - COALESCE(SUM(p.amount_paid), 0) as balance
      FROM students s
      LEFT JOIN challans c ON s.id = c.student_id AND c.academic_year_id = ? AND (c.status='pending' OR c.status='partial')
      LEFT JOIN payments p ON s.id = p.student_id
      WHERE $where
      GROUP BY s.id HAVING balance > 0 ORDER BY balance DESC''', [yearId, ...args]);
  }

  // ── Recent Payments (for dashboard) ──
  static Future<List<Map>> getRecentPayments({int limit = 8}) async {
    final d = await db;
    return d.rawQuery('''
      SELECT p.*, s.name as student_name, s.class, s.section, s.admission_no
      FROM payments p
      LEFT JOIN students s ON p.student_id = s.id
      ORDER BY p.id DESC LIMIT ?
    ''', [limit]);
  }

  // ── Low Stock Items (for dashboard) ──
  static Future<List<Map<String, dynamic>>> getLowStockItems({int threshold = 5}) async {
    final shop  = await (await db).query('shop_items',  where: 'stock <= ?', whereArgs: [threshold], orderBy: 'stock ASC');
    final books = await (await db).query('book_items',  where: 'stock <= ?', whereArgs: [threshold], orderBy: 'stock ASC');
    final result = <Map<String, dynamic>>[];
    for (final s in shop)  result.add({...s, 'item_type': 'Uniform/Shop'});
    for (final b in books) result.add({...b, 'item_type': 'Book'});
    result.sort((a, b) => (a['stock'] as int).compareTo(b['stock'] as int));
    return result;
  }

  // ── Shop Items ──
  static Future<List<Map>> getShopItems() async => (await db).query('shop_items', orderBy: 'name');
  static Future<int> insertShopItem(Map<String, dynamic> data) async => (await db).insert('shop_items', data);
  static Future<void> updateShopItem(int id, Map<String, dynamic> data) async =>
      (await db).update('shop_items', data, where: 'id = ?', whereArgs: [id]);
  static Future<void> deleteShopItem(int id) async =>
      (await db).delete('shop_items', where: 'id = ?', whereArgs: [id]);

  // ── Book Items ──
  static Future<List<Map>> getBookItems() async => (await db).query('book_items', orderBy: 'name');
  static Future<int> insertBookItem(Map<String, dynamic> data) async => (await db).insert('book_items', data);
  static Future<void> updateBookItem(int id, Map<String, dynamic> data) async =>
      (await db).update('book_items', data, where: 'id = ?', whereArgs: [id]);
  static Future<void> deleteBookItem(int id) async =>
      (await db).delete('book_items', where: 'id = ?', whereArgs: [id]);

  // ── Inventory Sales ──
  static Future<void> ensureInventoryTables() async {
    final d = await db;
    await d.execute('''CREATE TABLE IF NOT EXISTS inventory_sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT, bill_no TEXT NOT NULL,
      student_id INTEGER, student_name TEXT, student_class TEXT,
      student_section TEXT, admission_no TEXT, sale_date TEXT,
      subtotal REAL, discount_amount REAL DEFAULT 0, grand_total REAL,
      payment_mode TEXT, cheque_no TEXT, bank_name TEXT, remarks TEXT,
      sale_type TEXT DEFAULT 'shop',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');
    await d.execute('''CREATE TABLE IF NOT EXISTS inventory_sale_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL,
      item_type TEXT, item_id INTEGER, item_name TEXT, size TEXT,
      quantity INTEGER, unit_price REAL, total_price REAL)''');
    // Add sale_type column if missing (migration)
    try { await d.execute('ALTER TABLE inventory_sales ADD COLUMN sale_type TEXT DEFAULT \'shop\''); } catch (_) {}
  }

  static Future<String> insertInventorySale({
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
  }) async {
    await ensureInventoryTables();
    final d = await db;
    final billNo = 'BILL${DateTime.now().millisecondsSinceEpoch}';
    sale['bill_no'] = billNo;
    sale['sale_date'] = sale['sale_date'] ?? DateTime.now().toIso8601String().split('T')[0];
    final saleId = await d.insert('inventory_sales', sale);
    for (final item in items) {
      item['sale_id'] = saleId;
      await d.insert('inventory_sale_items', item);
      // Deduct stock
      if (item['item_type'] == 'shop') {
        final cur = await d.query('shop_items', where: 'id = ?', whereArgs: [item['item_id']]);
        if (cur.isNotEmpty) {
          final newStock = (cur.first['stock'] as int) - (item['quantity'] as int);
          await d.update('shop_items', {'stock': newStock < 0 ? 0 : newStock}, where: 'id = ?', whereArgs: [item['item_id']]);
        }
      } else if (item['item_type'] == 'book') {
        final cur = await d.query('book_items', where: 'id = ?', whereArgs: [item['item_id']]);
        if (cur.isNotEmpty) {
          final newStock = (cur.first['stock'] as int) - (item['quantity'] as int);
          await d.update('book_items', {'stock': newStock < 0 ? 0 : newStock}, where: 'id = ?', whereArgs: [item['item_id']]);
        }
      }
    }
    return billNo;
  }

  static Future<List<Map>> getInventorySalesByStudent(String studentName, String studentClass, String studentSection) async {
    await ensureInventoryTables();
    final d = await db;
    String where = 'sale_type = \'shop\'';
    final List args = [];
    if (studentName.isNotEmpty) { where += ' AND LOWER(student_name) = LOWER(?)'; args.add(studentName); }
    if (studentClass.isNotEmpty) { where += ' AND LOWER(student_class) = LOWER(?)'; args.add(studentClass); }
    if (studentSection.isNotEmpty) { where += ' AND LOWER(student_section) = LOWER(?)'; args.add(studentSection); }
    return d.query('inventory_sales', where: where, whereArgs: args, orderBy: 'created_at DESC');
  }

  static Future<List<Map>> getInventorySalesByStudentAll(String studentName, String studentClass, String studentSection) async {
    await ensureInventoryTables();
    final d = await db;
    String where = '1=1';
    final List args = [];
    if (studentName.isNotEmpty) { where += ' AND LOWER(student_name) = LOWER(?)'; args.add(studentName); }
    if (studentClass.isNotEmpty) { where += ' AND LOWER(student_class) = LOWER(?)'; args.add(studentClass); }
    if (studentSection.isNotEmpty) { where += ' AND LOWER(student_section) = LOWER(?)'; args.add(studentSection); }
    return d.query('inventory_sales', where: where, whereArgs: args, orderBy: 'created_at DESC');
  }
  static Future<List<Map>> getInventorySalesByStudentAndType(String studentName, String studentClass, String studentSection, String saleType) async {
    await ensureInventoryTables();
    final d = await db;
    String where = 'sale_type = ?';
    final List args = [saleType];
    if (studentName.isNotEmpty) { where += ' AND LOWER(student_name) = LOWER(?)'; args.add(studentName); }
    if (studentClass.isNotEmpty) { where += ' AND LOWER(student_class) = LOWER(?)'; args.add(studentClass); }
    if (studentSection.isNotEmpty) { where += ' AND LOWER(student_section) = LOWER(?)'; args.add(studentSection); }
    return d.query('inventory_sales', where: where, whereArgs: args, orderBy: 'created_at DESC');
  }

  static Future<List<Map>> getInventorySales({String? saleType}) async {
    await ensureInventoryTables();
    if (saleType != null) {
      return (await db).query('inventory_sales',
        where: 'sale_type = ?', whereArgs: [saleType],
        orderBy: 'created_at DESC');
    }
    return (await db).query('inventory_sales', orderBy: 'created_at DESC');
  }

  static Future<List<Map>> getInventorySaleItems(int saleId) async {
    await ensureInventoryTables();
    return (await db).query('inventory_sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  // ── Transport Locations ──
  static Future<void> ensureTransportTable() async {
    await (await db).execute('''CREATE TABLE IF NOT EXISTS transport_locations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      location TEXT NOT NULL,
      location_type TEXT NOT NULL DEFAULT 'Town',
      amount REAL NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');
    await (await db).execute('''CREATE TABLE IF NOT EXISTS transport_stops (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      location_id INTEGER NOT NULL,
      stop_name TEXT NOT NULL,
      amount REAL NOT NULL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP)''');
    await (await db).execute('''CREATE TABLE IF NOT EXISTS stop_term_amounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      stop_id INTEGER NOT NULL,
      period_label TEXT NOT NULL,
      amount REAL NOT NULL DEFAULT 0)''');
  }

  static Future<List<Map>> getTransportLocations() async {
    await ensureTransportTable();
    return (await db).query('transport_locations', orderBy: 'location ASC');
  }

  static Future<int> insertTransportLocation(String location, double amount, {String locationType = 'Town'}) async {
    await ensureTransportTable();
    return (await db).insert('transport_locations', {'location': location, 'location_type': locationType, 'amount': amount});
  }

  static Future<void> updateTransportLocation(int id, String location, double amount, {String locationType = 'Town'}) async {
    await ensureTransportTable();
    await (await db).update('transport_locations', {'location': location, 'location_type': locationType, 'amount': amount},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteTransportLocation(int id) async {
    await ensureTransportTable();
    await (await db).delete('transport_locations', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map>> getTransportStops(int locationId) async {
    await ensureTransportTable();
    return (await db).query('transport_stops',
        where: 'location_id = ?', whereArgs: [locationId], orderBy: 'id ASC');
  }

  static Future<int> insertTransportStop(int locationId, String stopName, double amount) async {
    await ensureTransportTable();
    return (await db).insert('transport_stops',
        {'location_id': locationId, 'stop_name': stopName, 'amount': amount});
  }

  static Future<void> updateTransportStop(int id, String stopName, double amount) async {
    await ensureTransportTable();
    await (await db).update('transport_stops', {'stop_name': stopName, 'amount': amount},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteTransportStop(int id) async {
    await ensureTransportTable();
    await (await db).delete('transport_stops', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getStopTermAmounts(int stopId) async {
    await ensureTransportTable();
    final rows = await (await db).query('stop_term_amounts',
        where: 'stop_id = ?', whereArgs: [stopId], orderBy: 'period_label ASC');
    if (rows.isNotEmpty) return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    // Auto-create Term 1/2/3 if none exist
    for (final label in ['Term 1', 'Term 2', 'Term 3']) {
      await (await db).insert('stop_term_amounts', {'stop_id': stopId, 'period_label': label, 'amount': 0});
    }
    return (await (await db).query('stop_term_amounts',
        where: 'stop_id = ?', whereArgs: [stopId], orderBy: 'period_label ASC'))
        .map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static Future<int> insertStopTermAmount(int stopId, String periodLabel, double amount) async {
    await ensureTransportTable();
    return (await db).insert('stop_term_amounts', {'stop_id': stopId, 'period_label': periodLabel, 'amount': amount});
  }

  static Future<void> updateStopTermAmount(int id, double amount) async {
    await ensureTransportTable();
    await (await db).update('stop_term_amounts', {'amount': amount}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map>> getAllInventoryItems() async {
    final shop = await getShopItems();
    final books = await getBookItems();
    final result = <Map>[];
    for (final s in shop) result.add({...s, 'item_type': 'shop', 'display': '${s['name']}${s['size'] != null ? ' (${s['size']})' : ''} - Uniform'});
    for (final b in books) result.add({...b, 'item_type': 'book', 'display': '${b['name']} - ${b['category'] ?? 'Book'}'});
    return result;
  }
}
