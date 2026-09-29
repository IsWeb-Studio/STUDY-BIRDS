import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/employee_repository.dart';
import '../../core/catalog_repository.dart';

class AdminUniversityAccountsScreen extends StatefulWidget {
  const AdminUniversityAccountsScreen({super.key});

  @override
  State<AdminUniversityAccountsScreen> createState() => _AdminUniversityAccountsScreenState();
}

class _AdminUniversityAccountsScreenState extends State<AdminUniversityAccountsScreen> {
  List<dynamic> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await EmployeeRepository.instance.getUniversityAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'تعذر تحميل حسابات الجامعات.';
        _loading = false;
      });
    }
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _CreateUniversityAccountScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'حسابات الجامعات',
      actions: [IconButton(onPressed: _openCreateForm, icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white))],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _accounts.isEmpty
                    ? EmptyState(icon: Icons.school_outlined, title: 'لا توجد حسابات جامعات', message: 'أنشئ حساب دخول لجامعة من زر الإضافة أعلى الشاشة.', ctaLabel: 'إنشاء حساب', onCta: _openCreateForm)
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _accounts.length,
                      itemBuilder: (context, i) {
                        final account = _accounts[i] as Map<String, dynamic>;
                        final linked = account['linkedUniversity'] as Map<String, dynamic>?;
                        final isActive = account['isActive'] != false;
                        return AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(account['name'] as String? ?? '—', style: AppTextStyles.cardTitle),
                                    Text(account['email'] as String? ?? '', style: AppTextStyles.caption),
                                    if (linked != null) Text('مرتبط بـ: ${linked['name']}', style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              StatusBadge(label: isActive ? 'نشط' : 'معطّل', color: isActive ? AppColors.success : AppColors.danger),
                            ],
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}

class _CreateUniversityAccountScreen extends StatefulWidget {
  const _CreateUniversityAccountScreen();

  @override
  State<_CreateUniversityAccountScreen> createState() => _CreateUniversityAccountScreenState();
}

class _CreateUniversityAccountScreenState extends State<_CreateUniversityAccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  List<dynamic> _universities = [];
  String? _selectedUniversityId;
  bool _loadingUniversities = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    CatalogRepository.instance.getUniversities().then((data) {
      if (mounted) setState(() {
        _universities = data;
        _loadingUniversities = false;
      });
    }).catchError((_) {
      if (mounted) setState(() {
        _error = 'تعذر تحميل قائمة الجامعات.';
        _loadingUniversities = false;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.isEmpty || _selectedUniversityId == null) {
      setState(() => _error = 'كل الحقول مطلوبة، ولازم تختار جامعة.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await EmployeeRepository.instance.createUniversityAccount(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        universityId: _selectedUniversityId!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'تعذر إنشاء الحساب.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController controller, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.button), border: Border.all(color: AppColors.border)),
            child: TextField(controller: controller, obscureText: obscure, textAlign: TextAlign.right, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إنشاء حساب جامعة',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('اسم صاحب الحساب', _name),
            _field('البريد الإلكتروني', _email),
            _field('كلمة المرور', _password, obscure: true),
            const Text('الجامعة', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.button), border: Border.all(color: AppColors.border)),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _loadingUniversities
                  ? const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator())
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedUniversityId,
                        hint: const Padding(padding: EdgeInsets.all(4), child: Text('اختر جامعة')),
                        items: _universities.map((u) {
                          final uni = u as Map<String, dynamic>;
                          return DropdownMenuItem(value: uni['_id'] as String, child: Text(uni['name'] as String? ?? '—'));
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedUniversityId = v),
                      ),
                    ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(label: _saving ? 'جاري الإنشاء...' : 'إنشاء الحساب', onPressed: _saving ? null : _submit),
          ],
        ),
      ),
    );
  }
}
