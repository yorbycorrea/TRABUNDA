import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mobile/features/auth/presentation/login_view_model.dart';
import 'package:mobile/features/auth/controller/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final LoginViewModel _viewModel = LoginViewModel();

  bool _obscure = true;
  String? _bannerError;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadVersion();
  }

  void _onViewModelChanged() {
    if (!mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  // ✅ Banner bonito (similar a “alerta”)
  Widget _errorBanner(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC9C9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Color(0xFFC62828)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos incorrectos',
                  style: TextStyle(
                    color: Color(0xFF8E1B1B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(color: Color(0xFFC62828))),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 18, color: Color(0xFFB71C1C)),
            onPressed: () => setState(() => _bannerError = null),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _bannerError = null;
    });

    final auth = AuthControllerScope.of(context);
    final ok = await auth.login(
      username: _user.text.trim(),
      password: _pass.text.trim(),
    );

    if (!mounted) return;

    if (!ok) {
      final raw = auth.errorMessage ?? 'No se puede iniciar sesion';
      setState(() {
        // ✅ aquí transformamos el error técnico a uno amigable
        _bannerError = _viewModel.friendlyError(raw);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final auth = AuthControllerScope.of(context);
    final isLoading = auth.status == AuthStatus.loading;

    // ✅ ahora usamos el banner ya “limpio”
    final rawBanner =
        (auth.status == AuthStatus.error ? auth.errorMessage : null) ??
        _bannerError;

    final bannerText = (rawBanner != null && rawBanner.trim().isNotEmpty)
        ? _viewModel.friendlyError(rawBanner)
        : null;

    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(
            painter: _WavesPainter(),
            size: Size(size.width, size.height),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Image.asset(
                    'assets/icon/logo.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ingreso de supervisores',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF0E2233),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                if (bannerText != null && bannerText.trim().isNotEmpty)
                  _errorBanner(bannerText),

                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _user,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa tu usuario';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _pass,
                            obscureText: _obscure,
                            onChanged: (_) {
                              if (_bannerError != null) {
                                setState(() => _bannerError = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () =>
                                          setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa tu Contraseña';
                              }
                              if (v.length < 8) {
                                return 'Minimo 8 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeAlign: 2,
                                      ),
                                    )
                                  : const Text('Entrar'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: isLoading ? null : () {},
                            child: const Text('Olvide mi contraseña'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TRABUNDA S.A.C . PROCESOS MARINOS',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7A8C),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_viewModel.appVersion.isNotEmpty)
                        Text(
                          _viewModel.appVersion,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF6B7A8C),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8F2FA), Color(0xFFF5F8FB)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final p1 = Path()
      ..lineTo(0, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.10,
        size.width * 0.50,
        size.height * 0.16,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.22,
        size.width,
        size.height * 0.14,
      )
      ..lineTo(size.width, 0)
      ..close();

    final paint1 = Paint()..color = const Color(0xFFD6E8F7);
    canvas.drawPath(p1, paint1);

    final p2 = Path()
      ..moveTo(0, size.height * 0.14)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.08,
        size.width * 0.55,
        size.height * 0.14,
      )
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 0.20,
        size.width,
        size.height * 0.12,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    final paint2 = Paint()..color = const Color(0xFFBEDAF1);
    canvas.drawPath(p2, paint2);

    final headerH = size.height * 0.10;
    final headerRect = Rect.fromLTWH(0, 0, size.width, headerH);
    final headerPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F5DAA), Color(0xFF1B81C2)],
      ).createShader(headerRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0);

    final header = Path()
      ..moveTo(0, 0)
      ..lineTo(0, headerH)
      ..quadraticBezierTo(
        size.width * 0.25,
        headerH - 18,
        size.width * 0.50,
        headerH - 14,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(header, headerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
