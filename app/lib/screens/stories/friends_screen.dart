import '../community/student_profile_link.dart';
import '../services_support/messaging_and_emergency_screens.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/repositories/friends_repository.dart';
import '../../core/widgets/student_achievements.dart';
import '../../core/widgets/app_notice.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _search = TextEditingController();
  final _repo = FriendsRepository.instance;
  final _busy = <String>{};
  List<StudentFriend> _people = [];
  Map<String, dynamic> _counts = {};
  String _kind = 'friends';
  String? _cursor, _error;
  bool _loading = false, _more = false;
  Timer? _debounce;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _more || _cursor == null)) return;
    final query = _search.text.trim();
    final generation = ++_generation;
    if (query.isNotEmpty && query.length < 2) {
      setState(() {
        _people = [];
        _cursor = null;
        _loading = false;
        _more = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = !more;
      _more = more;
      _error = null;
      if (!more) _people = [];
    });
    try {
      final page = await _repo.list(_kind,
          query: query.isEmpty ? null : query, before: more ? _cursor : null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _people = more
            ? [
                ..._people,
                ...page.people
                    .where((p) => !_people.any((old) => old.id == p.id))
              ]
            : page.people;
        _cursor = page.nextCursor;
        if (page.counts.isNotEmpty) _counts = page.counts;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _more = false;
          _error = e.toString();
        });
      }
    }
  }

  void _queryChanged(String value) {
    // Invalidate old results immediately, before the debounce fires.
    _generation++;
    _debounce?.cancel();
    setState(() {
      _people = [];
      _cursor = null;
      _loading = value.trim().length >= 2;
      _more = false;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () => _load());
  }

  Future<void> _action(StudentFriend person, String action) async {
    if (_busy.contains(person.id)) return;
    setState(() => _busy.add(person.id));
    try {
      await _repo.change(person.id, action);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(AppSnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(person.id));
    }
  }

  Future<void> _remove(StudentFriend person) async {
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('إزالة الصديق؟'),
                content:
                    Text('بعد إزالة ${person.name} لن تظهر يومياتكما لبعضكما.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('رجوع')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('إزالة'))
                ]));
    if (accepted == true && mounted) await _action(person, 'remove');
  }

  Widget _actions(StudentFriend person) {
    if (_busy.contains(person.id)) {
      return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    return switch (person.relation) {
      'friends' => Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton.icon(
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('مراسلة'),
              onPressed: () async {
                if (_busy.contains(person.id)) return;
                setState(() => _busy.add(person.id));
                try {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ConversationThreadScreen(
                          contactId: person.id,
                          contactName: person.name,
                          contactAvatar: person.avatar)));
                } finally {
                  if (mounted) setState(() => _busy.remove(person.id));
                }
              }),
          IconButton(
              onPressed: () => _remove(person),
              tooltip: 'إزالة الصديق',
              icon: const Icon(Icons.person_remove_outlined)),
        ]),
      'outgoing' => TextButton(
          onPressed: () => _action(person, 'remove'),
          child: const Text('إلغاء الطلب')),
      'incoming' => Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton(
              onPressed: () => _action(person, 'accept'),
              child: const Text('قبول')),
          IconButton(
              onPressed: () => _action(person, 'remove'),
              tooltip: 'رفض',
              icon: const Icon(Icons.close)),
        ]),
      _ => TextButton.icon(
          onPressed: () => _action(person, 'request'),
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('إضافة')),
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الأصدقاء'), actions: [
          IconButton(
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث')
        ]),
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                  controller: _search,
                  maxLength: 60,
                  onChanged: _queryChanged,
                  decoration: const InputDecoration(
                      hintText: 'ابحث عن زميل بالاسم',
                      prefixIcon: Icon(Icons.search),
                      counterText: '',
                      border: OutlineInputBorder()))),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                  'بعد قبول طلب الصداقة تقدروا تشوفوا يوميات بعض وتتفاعلوا معها.',
                  textAlign: TextAlign.center)),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                for (final item in const {
                  'friends': 'أصدقائي',
                  'incoming': 'طلبات واردة',
                  'outgoing': 'طلبات مرسلة'
                }.entries)
                  Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                          label: Text(
                              '${item.value}${_counts[item.key] == null ? '' : ' (${_counts[item.key]})'}'),
                          selected: _kind == item.key && _search.text.isEmpty,
                          onSelected: (_) {
                            _debounce?.cancel();
                            _search.clear();
                            setState(() => _kind = item.key);
                            _load();
                          })),
              ])),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            TextButton(
                onPressed: () => _load(),
                child: Text('تعذر التحميل. اضغط للمحاولة: $_error')),
          Expanded(
              child: RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (!_loading && _error == null && _people.isEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Column(children: [
                                const Icon(Icons.people_outline,
                                    size: 56, color: Colors.blueGrey),
                                const SizedBox(height: 12),
                                Text(
                                    _search.text.trim().length == 1
                                        ? 'اكتب حرفين على الأقل للبحث'
                                        : _search.text.isNotEmpty
                                            ? 'لا يوجد طلاب بهذا الاسم'
                                            : _kind == 'friends'
                                                ? 'أضف أصدقاء لتشوف يومياتهم هنا'
                                                : 'لا توجد طلبات صداقة',
                                    textAlign: TextAlign.center),
                              ])),
                        for (final person in _people)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(
                                              child: StudentIdentity(
                                                  id: person.id,
                                                  name: person.name,
                                                  avatar: person.avatar,
                                                  onClosed: () => _load())),
                                          StudentAchievementMark(
                                              points: person.points)
                                        ]),
                                        Align(
                                            alignment:
                                                AlignmentDirectional.centerEnd,
                                            child: _actions(person)),
                                      ]))),
                        if (_cursor != null)
                          TextButton(
                              onPressed: _more ? null : () => _load(more: true),
                              child: Text(_more ? 'جارٍ التحميل…' : 'المزيد')),
                      ]))),
        ])),
      );
}
