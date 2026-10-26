// First-run onboarding (issue #012): max 3 slides + optional name capture,
// skippable, shown exactly once — gated on `has_onboarded` by the caller
// (`HomeScreen`), not inferred from lesson activity.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../pet/pet_catalog.dart';
import '../pet/pet_providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';

/// Copy for one onboarding slide. All slides show the same equipped pet
/// (#059 retired the old per-slide empty/lit/on-fire states).
class _OnboardingSlideData {
  final String title;
  final String body;

  const _OnboardingSlideData({required this.title, required this.body});
}

/// Max-3-slide, skippable first-run flow. [onDone] is called exactly once
/// — on Skip (from any slide) or on finishing the last slide — with
/// whatever name is currently typed (possibly blank); the caller persists
/// it + marks onboarding done. Skip does not discard an already-typed name.
class OnboardingScreen extends ConsumerStatefulWidget {
  final Future<void> Function(String? name) onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.onDone(_nameController.text);
    } catch (_) {
      // Persisting failed (e.g. disk/DB error): re-enable Skip/Next instead
      // of leaving the user stuck on onboarding forever.
      if (mounted) setState(() => _finishing = false);
    }
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final pet = ref.watch(equippedPetProvider);
    final List<_OnboardingSlideData> slides = <_OnboardingSlideData>[
      _OnboardingSlideData(
        title: l10n.onboardingSlide1Title,
        body: l10n.onboardingSlide1Body,
      ),
      _OnboardingSlideData(
        title: l10n.onboardingSlide2Title,
        body: l10n.onboardingSlide2Body,
      ),
      _OnboardingSlideData(
        title: l10n.onboardingSlide3Title,
        body: l10n.onboardingSlide3Body,
      ),
    ];
    final bool isLast = _page == slides.length - 1;

    return Scaffold(
      key: const Key('onboardingScreen'),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(FoxSpacing.md),
                child: FoxSecondaryButton(
                  key: const Key('onboardingSkipButton'),
                  label: l10n.onboardingSkip,
                  onPressed: _finishing ? null : _finish,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int i) => setState(() => _page = i),
                children: <Widget>[
                  for (final _OnboardingSlideData slide in slides)
                    _OnboardingSlide(
                      data: slide,
                      pet: pet,
                      nameField: slide == slides.last
                          ? TextField(
                              key: const Key('onboardingNameField'),
                              controller: _nameController,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: l10n.onboardingNameHint,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FoxSpacing.xl),
              child: FoxPrimaryButton(
                key: const Key('onboardingNextButton'),
                label: isLast ? l10n.onboardingGetStarted : l10n.onboardingNext,
                expanded: true,
                isLoading: _finishing,
                onPressed: _finishing ? null : (isLast ? _finish : _next),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final _OnboardingSlideData data;
  final PetEntry pet;
  final Widget? nameField;

  const _OnboardingSlide({
    required this.data,
    required this.pet,
    this.nameField,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FoxSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FoxPet(pet: pet, size: 120),
            const SizedBox(height: FoxSpacing.xl),
            Text(
              data.title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FoxSpacing.md),
            Text(data.body, textAlign: TextAlign.center),
            if (nameField != null) ...<Widget>[
              const SizedBox(height: FoxSpacing.xl),
              nameField!,
            ],
          ],
        ),
      ),
    );
  }
}
