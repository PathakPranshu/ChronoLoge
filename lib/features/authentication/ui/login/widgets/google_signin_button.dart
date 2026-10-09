import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Theme
    final colorTheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(20, 50),
        overlayColor: colorTheme.outline,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        side: BorderSide(
          color: colorTheme.outline,
          strokeAlign: BorderSide.strokeAlignInside,
          width: 1,
        ),
      ),
      child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/google_icon.png",
                  width: 20,
                  height: 20,
                  cacheHeight: 100,
                  cacheWidth: 100,
                ),
                const SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: GoogleFonts.googleSans(
                    fontWeight: FontWeight(500),
                    fontSize: 16,
                    color: colorTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}
