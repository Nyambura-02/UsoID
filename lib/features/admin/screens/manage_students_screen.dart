import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uso_id/core/services/firestore_service.dart';
import 'package:uso_id/core/models/student.dart';
import 'package:uso_id/core/theme/app_theme.dart';
import 'package:uso_id/features/shared/widgets/section_header.dart';
import 'dart:io';
import 'package:csv/csv.dart';

class ManageStudentsScreen extends ConsumerStatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  ConsumerState<ManageStudentsScreen> createState() =>
      _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends ConsumerState<ManageStudentsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _importCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final rows =
          const CsvToListConverter(eol: '\n').convert(content);

      if (rows.length < 2) {
        _showSnack('CSV is empty or has no data rows', isError: true);
        return;
      }

      // Skip header row
      final dataRows = rows.skip(1).toList();
      final students = dataRows
          .where((row) => row.length >= 3)
          .map((row) => Student(
                schoolId: row[0].toString().trim(),
                fullName: row[1].toString().trim(),
                email: row[2].toString().trim(),
                courseCode: row.length > 3 ? row[3].toString().trim() : '',
                faceEnrolled: false,
              ))
          .toList();

      if (students.isEmpty) {
        _showSnack('No valid rows found in CSV', isError: true);
        return;
      }

      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.bulkAddStudents(students);

      _showSnack('Imported ${students.length} students successfully');
    } catch (e) {
      _showSnack('Import failed: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showAddStudentDialog() {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final courseCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (ctx2, setInner) => Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add Student',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: idCtrl,
                    decoration:
                        const InputDecoration(labelText: 'School ID'),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Full Name'),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'Email'),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: courseCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Course Code'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setInner(() => loading = true);
                            try {
                              final firestoreService =
                                  ref.read(firestoreServiceProvider);
                              await firestoreService.addStudent(
                                Student(
                                  schoolId: idCtrl.text.trim(),
                                  fullName: nameCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  courseCode: courseCtrl.text.trim(),
                                  faceEnrolled: false,
                                ),
                              );
                              if (ctx2.mounted) Navigator.pop(ctx2);
                              _showSnack('Student added');
                            } catch (e) {
                              _showSnack('Error: $e', isError: true);
                            } finally {
                              setInner(() => loading = false);
                            }
                          },
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white),
                          )
                        : const Text('Add Student'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = ref.read(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Students'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Import CSV',
            onPressed: _importCSV,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Student'),
        backgroundColor: AppTheme.primaryBlue,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or ID…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Student list
          Expanded(
            child: StreamBuilder<List<Student>>(
              stream: firestoreService.watchStudents(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data ?? [];
                final students = _searchQuery.isEmpty
                    ? all
                    : all
                        .where((s) =>
                            s.fullName
                                .toLowerCase()
                                .contains(_searchQuery) ||
                            s.schoolId.toLowerCase().contains(_searchQuery))
                        .toList();

                if (students.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No students yet. Import CSV or add manually.'
                          : 'No results for "$_searchQuery"',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final s = students[index];
                    return _StudentTile(student: s);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Student student;
  const _StudentTile({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.10),
          child: Text(
            student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: AppTheme.primaryBlue, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          student.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${student.schoolId}  ·  ${student.courseCode}'),
        trailing: Icon(
          student.faceEnrolled ? Icons.face : Icons.face_outlined,
          color: student.faceEnrolled ? AppTheme.success : AppTheme.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}
