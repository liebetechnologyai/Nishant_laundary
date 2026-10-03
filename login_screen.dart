import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final e164 = toE164(_phone.text);
    if (e164.isEmpty) {
      setState(() => _error = 'Enter a valid mobile number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: e164);
      if (mounted) setState(() => _otpSent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send the code. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (!RegExp(r'^[0-9]{4,8}$').hasMatch(code)) {
      setState(() => _error = 'Enter the code you received');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success the auth stream in main.dart swaps this screen for the home screen.
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.sms,
        phone: toE164(_phone.text),
        token: code,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Verification failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.local_laundry_service, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('LIEBE Laundry',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Sign in with your mobile number',
                      textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  if (!_otpSent)
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        prefixText: '+91  ',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendOtp(),
                    )
                  else
                    TextField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: InputDecoration(
                        labelText: 'Code sent to ${toE164(_phone.text)}',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _verify(),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : (_otpSent ? _verify : _sendOtp),
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_otpSent ? 'Verify & continue' : 'Send code'),
                  ),
                  if (_otpSent)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _otpSent = false;
                                _otp.clear();
                                _error = null;
                              }),
                      child: const Text('Use a different number'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
