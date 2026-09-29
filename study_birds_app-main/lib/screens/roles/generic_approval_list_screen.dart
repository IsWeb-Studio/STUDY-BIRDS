import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';

class StatusOption {
  final String value;
  final String label;
  final Color color;
  const StatusOption(this.value, this.label, this.color);
}

/// A generic "list of items awaiting a status decision" screen. Used by
/// several employee sections (agency-requests, student-arrivals, payouts,
/// verification, partner-students) that all follow the same shape: a list,
/// each item has a status, and the reviewer picks a new status.
class GenericApprovalListScreen extends StatelessWidget {
  final String title;
  final Future<List<dynamic>> Function() fetchItems;
  final String Function(Map<String, dynamic> item) itemTitle;
  final String Function(Map<String, dynamic> item) itemSubtitle;
  final String Function(Map<String, dynamic> item) idOf;
  final String Function(Map<String, dynamic> item) statusOf;
  final List<StatusOption> statusOptions;
  final Future<Map<String, dynamic>> Function(String id, String status) onDecide;
  final String emptyMessage;

  const GenericApprovalListScreen({
    super.key,
    required this.title,
    required this.fetchItems,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.idOf,
    required this.statusOf,
    required this.statusOptions,
    required this.onDecide,
    this.emptyMessage = 'لا توجد عناصر بعد.',
  });

  @override
  Widget build(BuildContext context) {
    return _GenericApprovalListBody(
      title: title,
      fetchItems: fetchItems,
      itemTitle: itemTitle,
      itemSubtitle: itemSubtitle,
      idOf: idOf,
      statusOf: statusOf,
      statusOptions: statusOptions,
      onDecide: onDecide,
      emptyMessage: emptyMessage,
    );
  }
}

class _GenericApprovalListBody extends StatefulWidget {
  final String title;
  final Future<List<dynamic>> Function() fetchItems;
  final String Function(Map<String, dynamic> item) itemTitle;
  final String Function(Map<String, dynamic> item) itemSubtitle;
  final String Function(Map<String, dynamic> item) idOf;
  final String Function(Map<String, dynamic> item) statusOf;
  final List<StatusOption> statusOptions;
  final Future<Map<String, dynamic>> Function(String id, String status) onDecide;
  final String emptyMessage;

  const _GenericApprovalListBody({
    required this.title,
    required this.fetchItems,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.idOf,
    required this.statusOf,
    required this.statusOptions,
    required this.onDecide,
    required this.emptyMessage,
  });

  @override
  State<_GenericApprovalListBody> createState() => _GenericApprovalListBodyState();
}

class _GenericApprovalListBodyState extends State<_GenericApprovalListBody> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  String? _actingOnId;

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
      final data = await widget.fetchItems();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'تعذر تحميل البيانات.';
        _loading = false;
      });
    }
  }

  Future<void> _decide(String id, String status) async {
    setState(() => _actingOnId = id);
    try {
      final updated = await widget.onDecide(id, status);
      if (!mounted) return;
      setState(() {
        _items = _items.map((item) => widget.idOf(item as Map<String, dynamic>) == id ? updated : item).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر تحديث الحالة')));
      }
    } finally {
      if (mounted) setState(() => _actingOnId = null);
    }
  }

  StatusOption _metaFor(String status) => widget.statusOptions.firstWhere(
        (o) => o.value == status,
        orElse: () => StatusOption(status, status, AppColors.neutral),
      );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(icon: Icons.inbox_outlined, title: 'لا توجد عناصر', message: widget.emptyMessage)
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i] as Map<String, dynamic>;
                        final id = widget.idOf(item);
                        final status = widget.statusOf(item);
                        final meta = _metaFor(status);

                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(widget.itemTitle(item), style: AppTextStyles.cardTitle)),
                                  StatusBadge(label: meta.label, color: meta.color),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(widget.itemSubtitle(item), style: AppTextStyles.caption),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: widget.statusOptions
                                    .where((o) => o.value != status)
                                    .map((o) => OutlinedButton(
                                          onPressed: _actingOnId == id ? null : () => _decide(id, o.value),
                                          style: OutlinedButton.styleFrom(foregroundColor: o.color, side: BorderSide(color: o.color)),
                                          child: Text(o.label),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}
