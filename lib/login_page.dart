import 'package:flutter/material.dart';

import 'account_page.dart';
import 'auth_repository.dart';
import 'text.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.auth,
    required this.ui,
    required this.onLoggedIn,
  });

  final AuthRepository auth;
  final UiSettings ui;
  final ValueChanged<AppUser> onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _contact = TextEditingController();
  final _code = TextEditingController();
  VerificationChallenge? _challenge;
  var _registering = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _contact.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    final password = _password.text;
    if (name.isEmpty || password.isEmpty) {
      setState(() => _error = tr(context, '請填名稱和密碼。', 'Enter a name and password.'));
      return;
    }
    if (_registering && _contact.text.trim().isEmpty) {
      setState(() => _error = tr(context, '請填電郵或電話。', 'Enter an email or phone number.'));
      return;
    }
    if (_registering) {
      final problem = AuthRepository.passwordProblem(password);
      if (problem != null) {
        setState(() => _error = shown(context, problem));
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        final challenge = await widget.auth.register(
          name: name,
          password: password,
          contact: _contact.text,
        );
        if (!mounted) return;
        setState(() {
          _busy = false;
          _challenge = challenge;
          _code.text = '';
        });
        return;
      }
      final user = await widget.auth.login(name: name, password: password);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _busy = false;
          _error = tr(context, '名稱或密碼不對。', 'That name or password is wrong.');
        });
        return;
      }
      widget.onLoggedIn(user);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = tr(context, '登入失敗：$error', 'Could not sign in: $error');
      });
    }
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    if (_busy || challenge == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.auth.verify(
        name: challenge.name,
        code: _code.text,
      );
      if (!mounted) return;
      widget.onLoggedIn(user);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = tr(context, '驗證失敗：$error', 'Could not verify: $error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ShareKit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () => widget.ui.setEnglish(!widget.ui.english),
                      child: Text(widget.ui.english ? '中文' : 'English'),
                    ),
                  ),
                  Text(
                    _challenge != null
                        ? tr(context, '確認電郵或電話後就可以使用。', 'Confirm your email or phone to continue.')
                        : _registering
                            ? tr(context, '建立帳號後就可以預約附近的物品。', 'Create an account to borrow nearby items.')
                            : tr(context, '登入後就可以預約附近的物品。', 'Sign in to borrow nearby items.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF3E4E62),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _challenge == null ? _form() : _verifyForm(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: tr(context, '名稱', 'Name'),
            fillColor: const Color(0xFFF4F1EB),
          ),
        ),
        if (_registering) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _contact,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: tr(context, '電郵或電話', 'Email or phone'),
              fillColor: const Color(0xFFF4F1EB),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: tr(context, '密碼', 'Password'),
            helperText: _registering
                ? tr(context, '至少 8 個字，要有英文字母和數字。', 'At least 8 characters, with letters and numbers.')
                : null,
            fillColor: const Color(0xFFF4F1EB),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _submit,
            child: Text(
            _busy
                ? tr(context, '請稍候…', 'Please wait…')
                : _registering
                    ? tr(context, '建立帳號', 'Create account')
                    : tr(context, '登入', 'Log in'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(shown(context, _error!), style: TextStyle(color: Colors.red.shade800)),
        ],
        const SizedBox(height: 4),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _registering = !_registering;
                  _error = null;
                }),
          child: Text(
            _registering
                ? tr(context, '已有帳號？登入', 'Already have an account? Log in')
                : tr(context, '還沒有帳號？註冊', 'No account yet? Register'),
          ),
        ),
      ],
    );
  }

  Widget _verifyForm() {
    final challenge = _challenge!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr(context, '驗證碼已準備好，請向 ${challenge.contact} 核對。', 'Check the code against ${challenge.contact}.')),
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            '這台裝置沒有接駁真實短訊，驗證碼是 ${challenge.code}。',
            'This device does not send a real text. The code is ${challenge.code}.',
          ),
          style: const TextStyle(color: Color(0xFF5E6A64), height: 1.4),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr(context, '驗證碼', 'Code'),
            fillColor: const Color(0xFFF4F1EB),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: Text(_busy ? tr(context, '請稍候…', 'Please wait…') : tr(context, '確認驗證碼', 'Confirm code')),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(shown(context, _error!), style: TextStyle(color: Colors.red.shade800)),
        ],
      ],
    );
  }
}
