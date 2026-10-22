import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/onboarding_prefs.dart';
import '../../../core/services/app_permissions_service.dart';

/// First run: three screens that explain the product to an adult shopkeeper.
///
/// The first version dressed the app as a toy: a cartoon phone mascot waving
/// inside a pastel circle, on a light-blue canvas. A shopkeeper deciding whether
/// to trust the system with their stock does not read that as software.
///
/// This version uses flat, printed-illustration artwork on warm paper stock, in
/// the register of a trade catalogue rather than a nursery. The colour is ink and
/// oxblood, not primary blue.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Warm paper, ink and oxblood. Kept local to onboarding so the rest of the app
  // keeps its blue identity.
  static const _paper = Color(0xFFF7F3EA);
  static const _paperEdge = Color(0xFFE3DACB);
  static const _ink = Color(0xFF17130F);
  static const _inkSoft = Color(0xFF5C554B);
  static const _oxblood = Color(0xFF7C2D33);

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Every device, accounted for',
      'subtitle':
          'Live stock across all your branches, down to the last IMEI number with zero discrepancy.',
      'image': 'assets/images/mascot_stock.png',
      'badge': '100% AUDITABLE',
    },
    {
      'title': 'Scan IMEI in seconds',
      'subtitle':
          'Verify devices, receive stock, and disburse customer loans — all straight from the counter.',
      'image': 'assets/images/mascot_scan.png',
      'badge': 'INSTANT LOOKUP',
    },
    {
      'title': 'Loans without the chaos',
      'subtitle':
          'Follow every instalment, send reminders before a due date passes, and close the day with a balanced collection sheet.',
      'image': 'assets/images/mascot_loans.png',
      'badge': 'SMART FINANCING',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() async {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // Omba ruhusa za Android (kamera, GPS, arifa, simu/SMS, files) kabla ya
      // kuingia — na maelezo mafupi kwa mtumiaji.
      await AppPermissionsService.requestEarlyPermissions(
        context,
        showRationale: true,
      );
      await OnboardingPrefs.markSeen();
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildPlate(slide['image'] as String),
                        const SizedBox(height: 26),
                        Text(
                          slide['badge'] as String,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            color: _oxblood,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          slide['title'] as String,
                          style: const TextStyle(
                            fontSize: 27,
                            height: 1.18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide['subtitle'] as String,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.58,
                            color: _inkSoft,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _currentPage ? 22 : 6,
                      height: 3,
                      decoration: BoxDecoration(
                        color: i == _currentPage ? _ink : _paperEdge,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 0, 24, 20 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  if (_currentPage > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 54),
                          side: const BorderSide(color: _paperEdge, width: 1.2),
                          foregroundColor: _ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _currentPage == _slides.length - 1
                            ? 'Get started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A printed plate rather than a bubble: the artwork is a scene, so it gets a
  /// frame with a hairline border and a caption rule, not a pastel circle.
  Widget _buildPlate(String asset) {
    return AspectRatio(
      aspectRatio: 3 / 2,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _paperEdge),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(asset, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone_iphone_rounded,
                size: 17, color: Color(0xFFF7F3EA)),
          ),
          const SizedBox(width: 10),
          const Text(
            'LIMS',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
              color: _ink,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () async {
              await OnboardingPrefs.markSeen();
              if (context.mounted) context.go('/login');
            },
            child: const Text(
              'Skip',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
