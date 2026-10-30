import 'package:flutter/material.dart';

/// The route owns search and selection state until its closing animation ends.
class ProfileCountryPicker extends StatefulWidget {
  final List<Map<String, dynamic>> countries;
  final bool multiple;
  final List<String> initialCodes;
  const ProfileCountryPicker(
      {super.key,
      required this.countries,
      this.multiple = false,
      this.initialCodes = const []});

  @override
  State<ProfileCountryPicker> createState() => _ProfileCountryPickerState();
}

class _ProfileCountryPickerState extends State<ProfileCountryPicker> {
  String _query = '';
  late final Set<String> _selected = widget.initialCodes.toSet();

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final filtered = widget.countries
        .where((country) => [
              country['name'],
              country['nameAr'],
              country['code']
            ]
                .whereType<String>()
                .any((value) => value.toLowerCase().contains(_query)))
        .toList();
    return SafeArea(
        child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const ValueKey('profile-country-search'),
                autofocus: true,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  labelText: ar
                      ? (widget.multiple
                          ? 'ابحث عن دولة دراسة'
                          : 'ابحث عن دولة')
                      : 'Search countries',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              )),
          Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                          ar ? 'لا توجد دول مطابقة' : 'No matching countries'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final country = filtered[index];
                        final code = '${country['code'] ?? ''}'.toUpperCase();
                        final title = ar
                            ? '${country['nameAr'] ?? country['name'] ?? ''}'
                            : '${country['name'] ?? country['nameAr'] ?? ''}';
                        if (!widget.multiple) {
                          return ListTile(
                              key: ValueKey('country-$code'),
                              title: Text(title),
                              subtitle:
                                  Text('${country['name'] ?? ''} · $code'),
                              onTap: () => Navigator.pop(context, country));
                        }
                        return CheckboxListTile(
                            key: ValueKey('country-$code'),
                            title: Text(title),
                            subtitle: Text('${country['name'] ?? ''} · $code'),
                            value: _selected.contains(code),
                            onChanged: (checked) => setState(() {
                                  if (checked == true) {
                                    _selected.add(code);
                                  } else {
                                    _selected.remove(code);
                                  }
                                }));
                      })),
          if (widget.multiple)
            Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, _selected.toList()),
                      child: Text(ar ? 'تم' : 'Done'),
                    ))),
        ]),
      ),
    ));
  }
}
