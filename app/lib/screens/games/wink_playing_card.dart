import 'package:flutter/material.dart';

/// Protocol card 11 remains the winker; numbered artwork 1–11 is bundled.
class WinkPlayingCard extends StatelessWidget {
  final bool revealed;
  final int? number;
  const WinkPlayingCard({super.key, required this.revealed, this.number});

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final validFace =
        revealed && number != null && number! >= 1 && number! <= 11;
    final asset = !validFace
        ? 'assets/images/games/covey_card_back.png'
        : number == 11
            ? 'assets/images/games/covey_card_winker.png'
            : 'assets/images/games/covey_card_$number.png';
    final label = !validFace
        ? (ar ? 'ظهر كرت مغلق' : 'Hidden card back')
        : number == 11
            ? (ar ? 'كرت الغمّاز' : 'Winker card')
            : (ar ? 'كرت رقم $number' : 'Card number $number');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Semantics(
            image: true,
            label: label,
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(asset,
                    key: ValueKey(asset),
                    fit: BoxFit.contain,
                    cacheWidth: 600,
                    gaplessPlayback: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
