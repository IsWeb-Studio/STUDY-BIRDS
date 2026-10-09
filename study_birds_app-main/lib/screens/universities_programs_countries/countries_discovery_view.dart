import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import 'catalog_detail.dart' show catalogAssetUrl;
import 'catalog_browser.dart' show catalogText;

class CountriesDiscoveryView extends StatefulWidget {
  final List<Map<String, dynamic>> countries;
  final Future<void> Function() onRefresh;
  final ValueChanged<Map<String, dynamic>> onCountryTap;
  const CountriesDiscoveryView(
      {super.key,
      required this.countries,
      required this.onRefresh,
      required this.onCountryTap});

  @override
  State<CountriesDiscoveryView> createState() => _CountriesDiscoveryViewState();
}

class _CountriesDiscoveryViewState extends State<CountriesDiscoveryView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final countries = widget.countries
        .where((country) =>
            catalogText(country['name'])
                .toLowerCase()
                .contains(_query.trim().toLowerCase()) ||
            '${country['code'] ?? ''}'
                .toLowerCase()
                .contains(_query.trim().toLowerCase()))
        .toList();
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: widget.onRefresh,
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth < 350
            ? 1
            : constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 700
                    ? 3
                    : 2;
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: const LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [AppColors.navy, Color(0xFF1D5775)]),
                      ),
                      child: Row(children: [
                        const Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('وجهتك الدراسية القادمة',
                                style: TextStyle(
                                    color: Color(0xFFFFC58A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 12),
                            Text('أين تبدأ رحلتك؟',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 8),
                            Text(
                                'اكتشف الدول، تعرّف على الحياة فيها،\nواختر الوجهة التي تناسب طموحك.',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.6)),
                          ],
                        )),
                        const SizedBox(width: 10),
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: .1),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: .2))),
                            child: const Icon(Icons.travel_explore_rounded,
                                color: Colors.white, size: 38)),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'إلى أين تريد الدراسة؟',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.navy),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(children: [
                      const Expanded(
                          child: Text('اكتشف وجهتك',
                              style: AppTextStyles.sectionLabel)),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFEEDD),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('${countries.length} وجهة',
                              style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700))),
                    ]),
                  ]),
            )),
            if (countries.isEmpty)
              const SliverToBoxAdapter(
                  child: Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'لم نجد هذه الوجهة',
                          message: 'جرّب البحث باسم دولة آخر.')))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 300 + (scale - 1).clamp(0, 2) * 170,
                  ),
                  delegate: SliverChildBuilderDelegate(
                      (context, index) => _CountryDestinationCard(
                          country: countries[index],
                          onTap: () => widget.onCountryTap(countries[index])),
                      childCount: countries.length),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _CountryDestinationCard extends StatelessWidget {
  final Map<String, dynamic> country;
  final VoidCallback onTap;
  const _CountryDestinationCard({required this.country, required this.onTap});

  String? get flag {
    final code = '${country['code'] ?? ''}'.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return null;
    return String.fromCharCodes(code.codeUnits.map((value) => value + 127397));
  }

  @override
  Widget build(BuildContext context) {
    final name = catalogText(country['name']);
    final image = catalogAssetUrl(country['heroImage']);
    final count = country['universityCount'];
    final language = catalogText(country['language']);
    return Semantics(
      button: true,
      label: name,
      child: Container(
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: [
          BoxShadow(
              color: AppColors.navy.withValues(alpha: .08),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ]),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  height: 132,
                  child: Stack(fit: StackFit.expand, children: [
                    if (image != null)
                      AppNetworkImage(image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 132,
                          errorWidget: const _DestinationFallback())
                    else
                      const _DestinationFallback(),
                    const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                          Colors.transparent,
                          Color(0x660C223A)
                        ]))),
                    PositionedDirectional(
                        top: 12,
                        start: 12,
                        child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .94),
                                borderRadius: BorderRadius.circular(12)),
                            child: flag != null
                                ? Text(flag!,
                                    style: const TextStyle(fontSize: 23))
                                : const Icon(Icons.location_on_outlined,
                                    color: AppColors.navy, size: 22))),
                  ])),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'وجهة دراسية' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle
                              .copyWith(fontSize: 18, height: 1.25)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.account_balance_outlined,
                            size: 14, color: AppColors.orange),
                        const SizedBox(width: 5),
                        Expanded(
                            child: Text(
                                count is num
                                    ? '$count جامعة'
                                    : 'استكشف الجامعات',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.navy))),
                      ]),
                      if (language.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(language,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption),
                      ],
                      const Spacer(),
                      Row(children: [
                        const Expanded(
                            child: Text('تعرّف على الوجهة',
                                style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700))),
                        Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                                color: Color(0xFFFFEEDD),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_forward_rounded,
                                color: AppColors.orange, size: 16)),
                      ]),
                    ]),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DestinationFallback extends StatelessWidget {
  const _DestinationFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF1D5775), AppColors.navy])),
        child: Center(
            child: Icon(Icons.public_rounded, size: 62, color: Colors.white38)),
      );
}
