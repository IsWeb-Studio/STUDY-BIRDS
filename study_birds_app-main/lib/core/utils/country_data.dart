import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class Country {
  final String nameAr;
  final String iso2;
  final String dialCode;
  const Country(this.nameAr, this.iso2, this.dialCode);

  String get flag {
    final u = iso2.toUpperCase().codeUnits;
    return String.fromCharCode(u[0] - 65 + 0x1F1E6) +
        String.fromCharCode(u[1] - 65 + 0x1F1E6);
  }
}

const kDefaultCountry = Country('المملكة العربية السعودية', 'SA', '966');

const List<Country> kCountries = [
  // الدول العربية
  Country('المملكة العربية السعودية', 'SA', '966'),
  Country('الإمارات العربية المتحدة', 'AE', '971'),
  Country('الكويت', 'KW', '965'),
  Country('قطر', 'QA', '974'),
  Country('البحرين', 'BH', '973'),
  Country('عُمان', 'OM', '968'),
  Country('الأردن', 'JO', '962'),
  Country('لبنان', 'LB', '961'),
  Country('سوريا', 'SY', '963'),
  Country('العراق', 'IQ', '964'),
  Country('مصر', 'EG', '20'),
  Country('ليبيا', 'LY', '218'),
  Country('تونس', 'TN', '216'),
  Country('الجزائر', 'DZ', '213'),
  Country('المغرب', 'MA', '212'),
  Country('السودان', 'SD', '249'),
  Country('اليمن', 'YE', '967'),
  Country('فلسطين', 'PS', '970'),
  Country('موريتانيا', 'MR', '222'),
  Country('الصومال', 'SO', '252'),
  Country('جيبوتي', 'DJ', '253'),
  Country('جزر القمر', 'KM', '269'),
  // وجهات الدراسة الشائعة
  Country('تركيا', 'TR', '90'),
  Country('المملكة المتحدة', 'GB', '44'),
  Country('الولايات المتحدة', 'US', '1'),
  Country('كندا', 'CA', '1'),
  Country('ألمانيا', 'DE', '49'),
  Country('فرنسا', 'FR', '33'),
  Country('إيطاليا', 'IT', '39'),
  Country('إسبانيا', 'ES', '34'),
  Country('هولندا', 'NL', '31'),
  Country('بلجيكا', 'BE', '32'),
  Country('السويد', 'SE', '46'),
  Country('النرويج', 'NO', '47'),
  Country('الدنمارك', 'DK', '45'),
  Country('فنلندا', 'FI', '358'),
  Country('سويسرا', 'CH', '41'),
  Country('النمسا', 'AT', '43'),
  Country('البرتغال', 'PT', '351'),
  Country('اليونان', 'GR', '30'),
  Country('بولندا', 'PL', '48'),
  Country('التشيك', 'CZ', '420'),
  Country('المجر', 'HU', '36'),
  Country('رومانيا', 'RO', '40'),
  Country('أستراليا', 'AU', '61'),
  Country('نيوزيلندا', 'NZ', '64'),
  Country('اليابان', 'JP', '81'),
  Country('الصين', 'CN', '86'),
  Country('كوريا الجنوبية', 'KR', '82'),
  Country('الهند', 'IN', '91'),
  Country('باكستان', 'PK', '92'),
  Country('بنغلاديش', 'BD', '880'),
  Country('إندونيسيا', 'ID', '62'),
  Country('ماليزيا', 'MY', '60'),
  Country('سنغافورة', 'SG', '65'),
  Country('تايلاند', 'TH', '66'),
  Country('الفلبين', 'PH', '63'),
  Country('روسيا', 'RU', '7'),
  Country('أوكرانيا', 'UA', '380'),
  Country('كازاخستان', 'KZ', '7'),
  Country('أوزبكستان', 'UZ', '998'),
  Country('إيران', 'IR', '98'),
  Country('أفغانستان', 'AF', '93'),
  Country('البرازيل', 'BR', '55'),
  Country('الأرجنتين', 'AR', '54'),
  Country('المكسيك', 'MX', '52'),
  Country('كولومبيا', 'CO', '57'),
  Country('تشيلي', 'CL', '56'),
  Country('بيرو', 'PE', '51'),
  Country('نيجيريا', 'NG', '234'),
  Country('إثيوبيا', 'ET', '251'),
  Country('كينيا', 'KE', '254'),
  Country('تنزانيا', 'TZ', '255'),
  Country('غانا', 'GH', '233'),
  Country('جنوب أفريقيا', 'ZA', '27'),
  Country('أذربيجان', 'AZ', '994'),
  Country('أرمينيا', 'AM', '374'),
  Country('جورجيا', 'GE', '995'),
  Country('قبرص', 'CY', '357'),
  Country('مالطا', 'MT', '356'),
  Country('أيرلندا', 'IE', '353'),
  Country('سلوفاكيا', 'SK', '421'),
  Country('سلوفينيا', 'SI', '386'),
  Country('كرواتيا', 'HR', '385'),
  Country('صربيا', 'RS', '381'),
  Country('البوسنة والهرسك', 'BA', '387'),
  Country('ألبانيا', 'AL', '355'),
  Country('مقدونيا الشمالية', 'MK', '389'),
  Country('بلغاريا', 'BG', '359'),
  Country('لاتفيا', 'LV', '371'),
  Country('ليتوانيا', 'LT', '370'),
  Country('إستونيا', 'EE', '372'),
  Country('بيلاروسيا', 'BY', '375'),
  Country('مولدوفا', 'MD', '373'),
  Country('سريلانكا', 'LK', '94'),
  Country('نيبال', 'NP', '977'),
  Country('ميانمار', 'MM', '95'),
  Country('فيتنام', 'VN', '84'),
  Country('كمبوديا', 'KH', '855'),
  Country('لاوس', 'LA', '856'),
  Country('منغوليا', 'MN', '976'),
  Country('تاجيكستان', 'TJ', '992'),
  Country('تركمانستان', 'TM', '993'),
  Country('قيرغيزستان', 'KG', '996'),
  Country('إريتريا', 'ER', '291'),
  Country('السنغال', 'SN', '221'),
  Country('مالي', 'ML', '223'),
  Country('بوركينا فاسو', 'BF', '226'),
  Country('كوت ديفوار', 'CI', '225'),
  Country('الكاميرون', 'CM', '237'),
  Country('الكونغو', 'CG', '242'),
  Country('الكونغو الديمقراطية', 'CD', '243'),
  Country('أنغولا', 'AO', '244'),
  Country('زامبيا', 'ZM', '260'),
  Country('زيمبابوي', 'ZW', '263'),
  Country('موزمبيق', 'MZ', '258'),
  Country('مدغشقر', 'MG', '261'),
  Country('أوغندا', 'UG', '256'),
  Country('رواندا', 'RW', '250'),
  Country('بوروندي', 'BI', '257'),
  Country('مالاوي', 'MW', '265'),
  Country('بوتسوانا', 'BW', '267'),
  Country('ناميبيا', 'NA', '264'),
  Country('سواتيني', 'SZ', '268'),
  Country('ليسوتو', 'LS', '266'),
  Country('كوبا', 'CU', '53'),
  Country('فنزويلا', 'VE', '58'),
  Country('الإكوادور', 'EC', '593'),
  Country('بوليفيا', 'BO', '591'),
  Country('باراغواي', 'PY', '595'),
  Country('أوروغواي', 'UY', '598'),
  Country('تايوان', 'TW', '886'),
  Country('هونغ كونغ', 'HK', '852'),
  Country('ماكاو', 'MO', '853'),
  Country('بروناي', 'BN', '673'),
  Country('تيمور الشرقية', 'TL', '670'),
  Country('بابوا غينيا الجديدة', 'PG', '675'),
  Country('فيجي', 'FJ', '679'),
  Country('جزر سليمان', 'SB', '677'),
  Country('فانواتو', 'VU', '678'),
  Country('ساموا', 'WS', '685'),
  Country('تونغا', 'TO', '676'),
  Country('كيريباس', 'KI', '686'),
  Country('غينيا', 'GN', '224'),
  Country('غينيا بيساو', 'GW', '245'),
  Country('غينيا الاستوائية', 'GQ', '240'),
  Country('غابون', 'GA', '241'),
  Country('إفريقيا الوسطى', 'CF', '236'),
  Country('تشاد', 'TD', '235'),
  Country('النيجر', 'NE', '227'),
  Country('بنين', 'BJ', '229'),
  Country('توغو', 'TG', '228'),
  Country('ليبيريا', 'LR', '231'),
  Country('سيراليون', 'SL', '232'),
  Country('غامبيا', 'GM', '220'),
  Country('الرأس الأخضر', 'CV', '238'),
  Country('ساو تومي وبرينسيبي', 'ST', '239'),
  Country('جزر سيشل', 'SC', '248'),
  Country('موريشيوس', 'MU', '230'),
  Country('جزر المالديف', 'MV', '960'),
  Country('سريلانكا', 'LK', '94'),
  Country('بوتان', 'BT', '975'),
  Country('إسرائيل', 'IL', '972'),
  Country('قبرص الشمالية', 'CY', '90392'),
  Country('ليختنشتاين', 'LI', '423'),
  Country('لوكسمبورغ', 'LU', '352'),
  Country('موناكو', 'MC', '377'),
  Country('أندورا', 'AD', '376'),
  Country('سان مارينو', 'SM', '378'),
  Country('الفاتيكان', 'VA', '379'),
  Country('آيسلندا', 'IS', '354'),
  Country('غرينلاند', 'GL', '299'),
  Country('جزر فارو', 'FO', '298'),
  Country('جامايكا', 'JM', '1876'),
  Country('هايتي', 'HT', '509'),
  Country('جمهورية الدومينيكان', 'DO', '1809'),
  Country('بورتوريكو', 'PR', '1787'),
  Country('ترينيداد وتوباغو', 'TT', '1868'),
  Country('باهاماس', 'BS', '1242'),
  Country('بربادوس', 'BB', '1246'),
  Country('سانت لوسيا', 'LC', '1758'),
  Country('غرينادا', 'GD', '1473'),
  Country('السلفادور', 'SV', '503'),
  Country('غواتيمالا', 'GT', '502'),
  Country('هندوراس', 'HN', '504'),
  Country('نيكاراغوا', 'NI', '505'),
  Country('كوستاريكا', 'CR', '506'),
  Country('بنما', 'PA', '507'),
];

/// يفتح شاشة اختيار رمز الدولة ويُعيد الدولة المختارة.
Future<Country?> showCountryPicker(BuildContext context) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CountryPickerSheet(),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _search = TextEditingController();
  List<Country> _filtered = kCountries;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final t = q.trim();
    setState(() {
      _filtered = t.isEmpty
          ? kCountries
          : kCountries
              .where((c) =>
                  c.nameAr.contains(t) ||
                  c.dialCode.contains(t) ||
                  c.iso2.toLowerCase().contains(t.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('اختر رمز الدولة',
                        style: AppTextStyles.screenTitle),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: _filter,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'ابحث عن دولة أو رمز...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.button),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.button),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.button),
                      borderSide: const BorderSide(
                          color: AppColors.navy, width: 1.5)),
                ),
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text('لا توجد نتائج',
                          style: AppTextStyles.caption))
                  : ListView.separated(
                      controller: scrollCtrl,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 64),
                      itemBuilder: (ctx, i) {
                        final c = _filtered[i];
                        return ListTile(
                          onTap: () => Navigator.of(context).pop(c),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          leading: Text(c.flag,
                              style: const TextStyle(fontSize: 28)),
                          title: Text(c.nameAr,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.navy.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('+${c.dialCode}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
