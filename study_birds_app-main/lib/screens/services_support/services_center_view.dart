import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';

class ServicesCenterView extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  final Future<void> Function() onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback onRequests;
  final IconData Function(String) iconFor;
  const ServicesCenterView(
      {super.key,
      required this.services,
      required this.onRefresh,
      required this.onOpen,
      required this.onRequests,
      required this.iconFor});

  @override
  State<ServicesCenterView> createState() => _ServicesCenterViewState();
}

class _ServicesCenterViewState extends State<ServicesCenterView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = widget.services
        .where((row) => '${row['title'] ?? ''} ${row['description'] ?? ''}'
            .toLowerCase()
            .contains(_query.trim().toLowerCase()))
        .toList();
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.navy,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _ServicesWelcome(onRequests: widget.onRequests),
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('كل ما تحتاجه، أقرب إليك', style: AppTextStyles.cardTitle),
                SizedBox(height: 4),
                Text('اختر الخدمة ودعنا نساعدك في الخطوة القادمة.',
                    style: AppTextStyles.caption),
              ],
            )),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFEEDD),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${widget.services.length} خدمات',
                  style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'ابحث عن خدمة...',
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.navy),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'لا توجد خدمات مطابقة',
                message: 'جرّب اسم خدمة آخر.')
          else
            ...visible.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ServicePhotoCard(
                      service: row,
                      icon: widget.iconFor('${row['title'] ?? ''}'),
                      onTap: () => widget.onOpen(row)),
                )),
        ],
      ),
    );
  }
}

class _ServicesWelcome extends StatelessWidget {
  final VoidCallback onRequests;
  const _ServicesWelcome({required this.onRequests});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(children: [
          Positioned.fill(
              child: Image.asset('assets/images/services/support.jpg',
                  fit: BoxFit.cover, excludeFromSemantics: true)),
          const Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [Color(0xF20C223A), Color(0x990C223A)]),
          ))),
          Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: Color(0xFFFFC58A), size: 15),
                  SizedBox(width: 6),
                  Text('معك في كل خطوة',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 18),
              const Text('خطوات أسهل.\nرحلة أهدأ.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.25,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text(
                  'من تجهيز أوراقك إلى الوصول والاستقرار،\nخدمات تساعدك على التركيز على مستقبلك.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.6)),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRequests,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.receipt_long_rounded, size: 17),
                label: const Text('متابعة طلباتي'),
              ),
            ]),
          ),
        ]),
      );
}

String _servicePhoto(String title) {
  final text = title.toLowerCase();
  if (RegExp('مطار|استقبال|طيران|سفر|airport|travel|arrival').hasMatch(text)) {
    return 'assets/images/services/travel.jpg';
  }
  if (RegExp('سكن|housing|accommodation').hasMatch(text)) {
    return 'assets/images/services/housing.jpg';
  }
  if (RegExp('تأمين|تامين|صح|insur|health').hasMatch(text)) {
    return 'assets/images/services/health.jpg';
  }
  if (RegExp('بنك|بنكي|bank|finance').hasMatch(text)) {
    return 'assets/images/services/finance.jpg';
  }
  if (RegExp('جامع|قبول|دراس|university|admission').hasMatch(text)) {
    return 'assets/images/explore/universities.jpg';
  }
  if (RegExp(
          'ترجم|تصديق|توثيق|إقام|اقام|تأشير|معادل|translat|certif|visa|residen')
      .hasMatch(text)) {
    return 'assets/images/services/documents.jpg';
  }
  return 'assets/images/services/support.jpg';
}

class _ServicePhotoCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final IconData icon;
  final VoidCallback onTap;
  const _ServicePhotoCard(
      {required this.service, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = '${service['title'] ?? ''}';
    final photo = _servicePhoto(title);
    final remote = '${service['image'] ?? service['imageUrl'] ?? ''}'.trim();
    final remoteUri = Uri.tryParse(remote);
    final hasRemote =
        remoteUri?.scheme == 'https' || remoteUri?.scheme == 'http';
    final description = '${service['description'] ?? ''}'
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
    final price = '${service['priceDescription'] ?? ''}'.trim();
    return Semantics(
      button: true,
      label: title,
      child: Container(
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: [
          BoxShadow(
              color: AppColors.navy.withValues(alpha: .06),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(children: [
            Positioned.fill(
                child: hasRemote
                    ? Image.network(remote,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) =>
                            Image.asset(photo, fit: BoxFit.cover))
                    : Image.asset(photo,
                        fit: BoxFit.cover, excludeFromSemantics: true)),
            const Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  stops: [0, .55, 1],
                  colors: [Colors.white, Color(0xF5FFFFFF), Color(0x200C223A)]),
            ))),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFFEEDD),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Icon(icon,
                                        color: AppColors.orange, size: 21)),
                                const SizedBox(height: 12),
                                Text(title,
                                    style: AppTextStyles.cardTitle
                                        .copyWith(fontSize: 17)),
                                const SizedBox(height: 6),
                                Text(
                                    description.isEmpty
                                        ? 'اطّلع على التفاصيل ومتطلبات طلب الخدمة.'
                                        : description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.caption
                                        .copyWith(height: 1.5)),
                                const SizedBox(height: 12),
                                Text(price.isEmpty ? 'السعر عند الطلب' : price,
                                    style: const TextStyle(
                                        color: AppColors.navy,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ],
                            )),
                        const SizedBox(width: 18),
                        Expanded(
                            child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .92),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward_rounded,
                                  color: AppColors.navy, size: 20)),
                        )),
                      ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
