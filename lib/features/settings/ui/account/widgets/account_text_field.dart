import 'package:flutter/material.dart';

class AccountTextField extends StatefulWidget {
  const AccountTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.enabled = true,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
  });

  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;
  final bool enabled;
  final bool isPassword;
  final TextInputType keyboardType;

  @override
  State<AccountTextField> createState() => _AccountTextFieldState();
}

class _AccountTextFieldState extends State<AccountTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: Icon(widget.prefixIcon),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: widget.enabled
                    ? () => setState(() => _obscureText = !_obscureText)
                    : null,
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: colors.onSurfaceVariant,
                  size: 18,
                ),
              )
            : null,
      ),
    );
  }
}