import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../utils/device_country.dart';

/// [IntlPhoneField] that pre-selects country from device location (or locale).
class LocalePhoneField extends StatefulWidget {
  const LocalePhoneField({
    super.key,
    required this.controller,
    required this.decoration,
    required this.style,
    required this.dropdownTextStyle,
    this.onChanged,
    this.onSaved,
    this.autovalidateMode,
    this.flagsButtonPadding,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle style;
  final TextStyle dropdownTextStyle;
  final ValueChanged<PhoneNumber>? onChanged;
  final FormFieldSetter<PhoneNumber>? onSaved;
  final AutovalidateMode? autovalidateMode;
  final EdgeInsets? flagsButtonPadding;

  @override
  State<LocalePhoneField> createState() => _LocalePhoneFieldState();
}

class _LocalePhoneFieldState extends State<LocalePhoneField> {
  String _countryCode = DeviceCountry.fromDeviceLocale();
  bool _resolving = true;

  @override
  void initState() {
    super.initState();
    _resolveCountry();
  }

  Future<void> _resolveCountry() async {
    final code = await DeviceCountry.resolveFromLocation();
    if (!mounted) return;
    setState(() {
      _countryCode = code;
      _resolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      key: ValueKey('phone_$_countryCode'),
      controller: widget.controller,
      initialCountryCode: _countryCode,
      autovalidateMode: widget.autovalidateMode,
      onSaved: widget.onSaved,
      onChanged: widget.onChanged,
      decoration: widget.decoration.copyWith(
        suffixIcon: _resolving
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : widget.decoration.suffixIcon,
      ),
      disableLengthCheck: false,
      dropdownTextStyle: widget.dropdownTextStyle,
      style: widget.style,
      flagsButtonPadding:
          widget.flagsButtonPadding ?? const EdgeInsets.only(left: 8),
    );
  }
}
