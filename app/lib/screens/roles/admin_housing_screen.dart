import 'package:flutter/material.dart';

import '../../core/config/app_theme.dart';
import '../../core/repositories/admin_modules_repository.dart';
import '../../core/utils/json_safe.dart';

class AdminHousingScreen extends StatefulWidget {
  const AdminHousingScreen({super.key});
  @override
  State<AdminHousingScreen> createState() => _AdminHousingScreenState();
}

class _AdminHousingScreenState extends State<AdminHousingScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AdminModulesRepository.instance;
  List<Map<String, dynamic>> _listings = [],
      _bookings = [],
      _universities = [],
      _arrivals = [];
  bool _loading = true, _busy = false;
  String? _error;
  late final TabController _tabs = TabController(length: 3, vsync: this);
  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _repo.getAccommodationListings(),
        _repo.getAccommodationBookings(),
        _repo.getAdminUniversities(),
        AdminModulesRepository.instance.getArrivalRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _listings = _maps(values[0]);
        _bookings = _maps(values[1]);
        _universities = _maps(values[2]);
        _arrivals = _maps(values[3])
            .where((item) =>
                Json.mapOrNull(item['services'])?['studentHousing'] == true)
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _maps(List<dynamic> values) => values
      .whereType<Map>()
      .map((value) => Map<String, dynamic>.from(value))
      .toList();

  Future<void> _editListing([Map<String, dynamic>? listing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HousingListingEditor(
        listing: listing,
        universities: _universities,
        save: (payload) => _repo.saveAccommodationListing(
            listing?['_id']?.toString(), payload),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> listing) async {
    final ok = await showAppConfirmDialog(
      context,
      title: _ar ? 'حذف خيار السكن' : 'Delete housing listing',
      message: _ar
          ? 'لن يُحذف الخيار إذا كان له سجل حجوزات؛ عندها أخفه بدلًا من ذلك.'
          : 'Listings with booking history cannot be deleted; deactivate them instead.',
      confirmLabel: _ar ? 'حذف' : 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.deleteAccommodationListing('${listing['_id']}');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bookingAction(
      Map<String, dynamic> booking, String status) async {
    final student = Json.mapOrNull(booking['student']) ?? {};
    final listing = Json.mapOrNull(booking['listing']) ?? {};
    final noteController =
        TextEditingController(text: '${booking['staffNote'] ?? ''}');
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ar ? 'ملاحظة فريق السكن' : 'Housing team note'),
        content: TextField(
          controller: noteController,
          maxLength: 2000,
          maxLines: 3,
          decoration:
              InputDecoration(labelText: _ar ? 'ملاحظة للطلب' : 'Booking note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, noteController.text.trim()),
            child: Text(_ar ? 'متابعة' : 'Continue'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || !mounted) return;
    final ok = await showAppConfirmDialog(
      context,
      title: _ar ? 'تحديث طلب الحجز' : 'Update booking request',
      message: _ar
          ? 'تأكيد ${status == 'confirmed' ? 'قبول' : status == 'rejected' ? 'رفض' : 'إلغاء'} طلب ${student['name'] ?? ''} لخيار ${listing['title'] ?? ''}؟'
          : 'Confirm $status for ${student['name'] ?? 'the student'} at ${listing['title'] ?? 'this listing'}?',
      confirmLabel: _ar ? 'تأكيد' : 'Confirm',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.updateAccommodationBooking(
        '${booking['_id']}',
        status: status,
        version: (booking['__v'] as num?)?.toInt() ?? 0,
        staffNote: note,
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _arrivalAction(
      Map<String, dynamic> request, String status) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.updateArrivalServiceStatus(
        request['_id'].toString(),
        serviceKey: 'studentHousing',
        serviceStatus: status,
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return AppScaffold(
      title: ar ? 'السكن الطلابي' : 'Student housing',
      body: _loading
          ? const LoadingState()
          : _error != null && _listings.isEmpty && _bookings.isEmpty
              ? ErrorState(message: _error!, onRetry: _load)
              : Column(children: [
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      labelColor: AppColors.navy,
                      indicatorColor: AppColors.green,
                      tabs: [
                        Tab(
                            text: ar
                                ? 'خيارات السكن (${_listings.length})'
                                : 'Listings (${_listings.length})'),
                        Tab(
                            text: ar
                                ? 'الحجوزات (${_bookings.length})'
                                : 'Bookings (${_bookings.length})'),
                        Tab(
                            text: ar
                                ? 'طلبات الوصول (${_arrivals.length})'
                                : 'Arrival requests (${_arrivals.length})'),
                      ]),
                  Expanded(
                      child: TabBarView(controller: _tabs, children: [
                    _listingsTab(),
                    _bookingsTab(),
                    _arrivalsTab(),
                  ])),
                ]),
    );
  }

  Widget _listingsTab() => RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
                onPressed: _busy ? null : () => _editListing(),
                icon: const Icon(Icons.add),
                label: Text(_ar ? 'إضافة خيار' : 'Add listing'))),
        if (_listings.isEmpty)
          EmptyState(
              icon: Icons.home_work_outlined,
              title: _ar ? 'لا توجد خيارات سكن' : 'No housing listings',
              message: _ar
                  ? 'أضف خيارًا من الكتالوج عند الحاجة.'
                  : 'Add a housing option when needed.'),
        for (final listing in _listings)
          Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${listing['title'] ?? ''}',
                            style: AppTextStyles.cardTitle),
                        Text(
                            '${_universityName(listing)} · ${_typeName('${listing['type'] ?? ''}')} · ${listing['price'] ?? 0} ${listing['currency'] ?? 'USD'} · ${_ar ? 'السعة' : 'Capacity'} ${listing['capacity'] ?? 0}',
                            style: AppTextStyles.caption),
                        if (listing['isActive'] != true)
                          Text(_ar ? 'مخفي عن الطلاب' : 'Hidden from students',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        if ((listing['amenities'] as List?)?.isNotEmpty == true)
                          Text((listing['amenities'] as List).join(' · ')),
                        OverflowBar(
                            alignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _editListing(listing),
                                  child: Text(_ar ? 'تعديل' : 'Edit')),
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _confirmDelete(listing),
                                  child: Text(_ar ? 'حذف' : 'Delete')),
                            ]),
                      ]))),
      ]));

  Widget _bookingsTab() => RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        if (_bookings.isEmpty)
          EmptyState(
              icon: Icons.event_busy_outlined,
              title: _ar ? 'لا توجد طلبات حجز' : 'No booking requests',
              message: _ar
                  ? 'ستظهر حجوزات الطلاب هنا.'
                  : 'Student bookings will appear here.'),
        for (final booking in _bookings) _bookingCard(booking),
      ]));

  Widget _bookingCard(Map<String, dynamic> booking) {
    final student = Json.mapOrNull(booking['student']) ?? {};
    final listing = Json.mapOrNull(booking['listing']) ?? {};
    final status = '${booking['status'] ?? ''}';
    return Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${student['name'] ?? (_ar ? 'طالب' : 'Student')} · ${listing['title'] ?? ''}',
                  style: AppTextStyles.cardTitle),
              Text(
                  '${_universityName(listing)} · ${_typeName('${listing['type'] ?? ''}')} · ${_statusName(status)}',
                  style: AppTextStyles.caption),
              if (booking['moveInDate'] != null)
                Text(
                    '${_ar ? 'تاريخ الانتقال:' : 'Move-in:'} ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse('${booking['moveInDate']}').toLocal())}'),
              if ('${booking['notes'] ?? ''}'.isNotEmpty)
                Text('${booking['notes']}'),
              if ('${booking['staffNote'] ?? ''}'.isNotEmpty)
                Text(
                    '${_ar ? 'ملاحظة الفريق:' : 'Team note:'} ${booking['staffNote']}'),
              if (!_busy && status == 'pending')
                Wrap(alignment: WrapAlignment.end, children: [
                  TextButton(
                      onPressed: () => _bookingAction(booking, 'confirmed'),
                      child: Text(_ar ? 'تأكيد' : 'Confirm')),
                  TextButton(
                      onPressed: () => _bookingAction(booking, 'rejected'),
                      child: Text(_ar ? 'رفض' : 'Reject')),
                ]),
              if (!_busy && status == 'confirmed')
                Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                        onPressed: () => _bookingAction(booking, 'cancelled'),
                        child: Text(_ar ? 'إلغاء الحجز' : 'Cancel booking'))),
            ])));
  }

  Widget _arrivalsTab() => RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        if (_arrivals.isEmpty)
          EmptyState(
              icon: Icons.flight_land_outlined,
              title: _ar
                  ? 'لا توجد طلبات سكن عبر الوصول'
                  : 'No housing arrival requests',
              message: _ar
                  ? 'الطلبات التي تتضمن خدمة السكن ستظهر هنا.'
                  : 'Arrival requests that include housing appear here.'),
        for (final request in _arrivals)
          Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                    '${Json.mapOrNull(request['student'])?['name'] ?? (_ar ? 'طالب' : 'Student')}'),
                subtitle: Text(
                    '${_ar ? 'الحالة:' : 'Status:'} ${request['status'] ?? ''} · ${request['arrivalDate'] ?? ''}'),
                trailing: PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (value) => _arrivalAction(request, value),
                    itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'in-progress',
                              child: Text(_ar ? 'قيد التنفيذ' : 'In progress')),
                          PopupMenuItem(
                              value: 'completed',
                              child: Text(_ar ? 'مكتمل' : 'Completed')),
                        ]),
              )),
      ]));

  String _universityName(Map<String, dynamic> data) =>
      '${Json.mapOrNull(data['university'])?['name'] ?? ''}';
  String _typeName(String type) => switch (type) {
        'single' => _ar ? 'فردي' : 'Single',
        'shared' => _ar ? 'مشترك' : 'Shared',
        'apartment' => _ar ? 'شقة طلابية' : 'Apartment',
        _ => type
      };
  String _statusName(String status) => switch (status) {
        'pending' => _ar ? 'قيد المراجعة' : 'Pending',
        'confirmed' => _ar ? 'مؤكد' : 'Confirmed',
        'rejected' => _ar ? 'مرفوض' : 'Rejected',
        'cancelled' => _ar ? 'ملغى' : 'Cancelled',
        _ => status
      };
}

class _HousingListingEditor extends StatefulWidget {
  final Map<String, dynamic>? listing;
  final List<Map<String, dynamic>> universities;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) save;
  const _HousingListingEditor(
      {required this.listing, required this.universities, required this.save});
  @override
  State<_HousingListingEditor> createState() => _HousingListingEditorState();
}

class _HousingListingEditorState extends State<_HousingListingEditor> {
  final _form = GlobalKey<FormState>();
  late final _title =
      TextEditingController(text: '${widget.listing?['title'] ?? ''}');
  late final _distance = TextEditingController(
      text: '${widget.listing?['distanceFromCampusKm'] ?? ''}');
  late final _amenities = TextEditingController(
      text: (widget.listing?['amenities'] as List? ?? []).join(', '));
  late final _price =
      TextEditingController(text: '${widget.listing?['price'] ?? ''}');
  late final _currency =
      TextEditingController(text: '${widget.listing?['currency'] ?? 'USD'}');
  late final _capacity =
      TextEditingController(text: '${widget.listing?['capacity'] ?? '1'}');
  late final _rules =
      TextEditingController(text: '${widget.listing?['rules'] ?? ''}');
  late String _type = '${widget.listing?['type'] ?? 'single'}';
  late String _university =
      '${Json.mapOrNull(widget.listing?['university'])?['_id'] ?? ''}';
  late bool _active = widget.listing?['isActive'] != false;
  bool _saving = false;
  String? _error;
  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  @override
  void dispose() {
    _title.dispose();
    _distance.dispose();
    _amenities.dispose();
    _price.dispose();
    _currency.dispose();
    _capacity.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final distance = _distance.text.trim().isEmpty
        ? null
        : double.tryParse(_distance.text.trim());
    final price = double.tryParse(_price.text.trim());
    final capacity = int.tryParse(_capacity.text.trim());
    final amenities = _amenities.text
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (price == null ||
        capacity == null ||
        (_distance.text.trim().isNotEmpty && distance == null) ||
        amenities.length > 30 ||
        amenities.any((item) => item.length > 100)) {
      setState(() => _error = _ar
          ? 'تحقق من السعر والمسافة والسعة والمرافق.'
          : 'Check price, distance, capacity and amenities.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save({
        'title': _title.text.trim(),
        'type': _type,
        'university': _university,
        'distanceFromCampusKm': distance,
        'amenities': amenities,
        'price': price,
        'currency': _currency.text.trim(),
        'capacity': capacity,
        'rules': _rules.text.trim(),
        'isActive': _active,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    final availableUniversityIds =
        widget.universities.map((item) => '${item['_id']}').toSet();
    final hasLegacyUniversity =
        _university.isNotEmpty && !availableUniversityIds.contains(_university);
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Form(
          key: _form,
          child: ListView(shrinkWrap: true, children: [
            Text(
                widget.listing == null
                    ? (ar ? 'إضافة خيار سكن' : 'Add housing listing')
                    : (ar ? 'تعديل خيار السكن' : 'Edit housing listing'),
                style: AppTextStyles.sectionLabel),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            TextFormField(
                controller: _title,
                maxLength: 200,
                validator: (v) => v == null || v.trim().isEmpty
                    ? (ar ? 'أدخل العنوان' : 'Enter a title')
                    : null,
                decoration:
                    InputDecoration(labelText: ar ? 'العنوان' : 'Title')),
            DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(labelText: ar ? 'النوع' : 'Type'),
                items: [
                  DropdownMenuItem(
                      value: 'single', child: Text(ar ? 'فردي' : 'Single')),
                  DropdownMenuItem(
                      value: 'shared', child: Text(ar ? 'مشترك' : 'Shared')),
                  DropdownMenuItem(
                      value: 'apartment',
                      child: Text(ar ? 'شقة طلابية' : 'Apartment')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value ?? 'single')),
            DropdownButtonFormField<String>(
              initialValue: _university.isEmpty ? null : _university,
              decoration:
                  InputDecoration(labelText: ar ? 'الجامعة' : 'University'),
              validator: (v) => v == null || v.isEmpty
                  ? (ar ? 'اختر جامعة' : 'Choose a university')
                  : null,
              items: [
                if (hasLegacyUniversity)
                  DropdownMenuItem(
                      value: _university,
                      child: Text(ar
                          ? 'جامعة غير متاحة حاليًا'
                          : 'Unavailable university')),
                for (final university in widget.universities)
                  DropdownMenuItem(
                      value: '${university['_id']}',
                      child: Text('${university['name'] ?? ''}')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _university = value ?? ''),
            ),
            TextFormField(
                controller: _distance,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v != null &&
                        v.trim().isNotEmpty &&
                        (double.tryParse(v) == null || double.parse(v) < 0)
                    ? (ar ? 'أدخل مسافة صحيحة' : 'Enter a valid distance')
                    : null,
                decoration: InputDecoration(
                    labelText: ar
                        ? 'المسافة من الحرم (كم)'
                        : 'Distance from campus (km)')),
            TextFormField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v == null ||
                        double.tryParse(v) == null ||
                        double.parse(v) < 0
                    ? (ar ? 'أدخل سعرًا صحيحًا' : 'Enter a valid price')
                    : null,
                decoration: InputDecoration(
                    labelText: ar ? 'السعر الشهري' : 'Monthly price')),
            TextFormField(
                controller: _currency,
                maxLength: 10,
                decoration:
                    InputDecoration(labelText: ar ? 'العملة' : 'Currency')),
            TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || int.tryParse(v) == null || int.parse(v) < 0
                        ? (ar ? 'أدخل سعة صحيحة' : 'Enter a valid capacity')
                        : null,
                decoration:
                    InputDecoration(labelText: ar ? 'السعة' : 'Capacity')),
            TextFormField(
                controller: _amenities,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: ar
                        ? 'المرافق، مفصولة بفواصل'
                        : 'Amenities, comma separated')),
            TextFormField(
                controller: _rules,
                maxLength: 2000,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: ar ? 'القواعد والشروط' : 'Rules and terms')),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged:
                    _saving ? null : (value) => setState(() => _active = value),
                title: Text(ar ? 'ظاهر للطلاب' : 'Visible to students')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(ar ? 'حفظ' : 'Save')),
          ])),
    );
  }
}
