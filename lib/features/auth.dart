import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'shell.dart';

Future<void>? _googleInitialization;
Future<AuthCredential> nativeGoogleCredential() async {
  _googleInitialization ??= GoogleSignIn.instance.initialize();
  await _googleInitialization;
  final google = await GoogleSignIn.instance.authenticate();
  return GoogleAuthProvider.credential(idToken: google.authentication.idToken);
}

Future<void> googleLogin({bool link = false}) async {
  if (kIsWeb) {
    if (link) {
      await FirebaseAuth.instance.currentUser!.linkWithPopup(
        GoogleAuthProvider(),
      );
    } else {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    }
  } else {
    final credential = await nativeGoogleCredential();
    if (link) {
      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
    } else {
      await FirebaseAuth.instance.signInWithCredential(credential);
    }
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return snapshot.data == null
          ? const LoginPage()
          : SessionGate(key: ValueKey(snapshot.data!.uid));
    },
  );
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late Future<Session> future;
  final invitation = TextEditingController();
  @override
  void initState() {
    super.initState();
    invitation.text = Uri.base.queryParameters['invite'] ?? '';
    future = load();
  }

  Future<Session> load() async {
    if (invitation.text.isNotEmpty &&
        FirebaseAuth.instance.currentUser?.emailVerified == true) {
      await Api.call('acceptInvitation', {'token': invitation.text.trim()});
      invitation.clear();
    }
    final s = Session(await Api.call('session'));
    await s.load();
    return s;
  }

  void retry() {
    setState(() => future = load());
  }

  @override
  void dispose() {
    invitation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Session>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) return AppShell(session: snapshot.data!);
      if (!snapshot.hasError) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Brand(),
                      const SizedBox(height: 32),
                      Text(
                        'Completa tu acceso',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        readableError(snapshot.error!),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: invitation,
                        decoration: const InputDecoration(
                          labelText: 'Código de invitación',
                          hintText: 'Pega el código recibido de DTS',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          try {
                            await Api.call('acceptInvitation', {
                              'token': invitation.text.trim(),
                            });
                            invitation.clear();
                            retry();
                          } catch (e) {
                            if (context.mounted) {
                              toast(context, readableError(e), error: true);
                            }
                          }
                        },
                        child: const Text('Aceptar invitación'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await FirebaseAuth.instance.currentUser!
                                .sendEmailVerification();
                            if (context.mounted) {
                              toast(
                                context,
                                'Revisa tu correo y verifica tu cuenta.',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              toast(context, readableError(e), error: true);
                            }
                          }
                        },
                        child: const Text('Enviar correo de verificación'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.currentUser!.reload();
                          await FirebaseAuth.instance.currentUser!.getIdToken(
                            true,
                          );
                          retry();
                        },
                        child: const Text('Ya verifiqué / Volver a intentar'),
                      ),
                      TextButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, register = false, visible = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, c) => Row(
        children: [
          if (c.maxWidth > 950)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF082E4B),
                      Color(0xFF0A3D62),
                      Color(0xFF126294),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Brand(light: true),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'DESARROLLO & TECNOLOGÍA SANTANDER',
                        style: TextStyle(
                          color: gold,
                          fontSize: 11,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Cada proyecto.\nCada cliente.\nTodo conectado.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Un espacio para acompañar tus proyectos,\nresolver solicitudes y construir mejores relaciones.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _LoginFeature(Icons.business_outlined, 'Clientes'),
                        _LoginFeature(Icons.layers_outlined, 'Proyectos'),
                        _LoginFeature(Icons.support_agent, 'Soporte'),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'Tecnología cercana. Soluciones que avanzan contigo.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(c.maxWidth < 600 ? 24 : 56),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (c.maxWidth <= 950) ...[
                          const Brand(),
                          const SizedBox(height: 40),
                        ],
                        Row(
                          children: [
                            const StatusBadge('QA'),
                            const SizedBox(width: 8),
                            Text(
                              'ENTORNO DE PRUEBAS',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          register ? 'Crea tu cuenta' : 'Bienvenido a DTS',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          register
                              ? 'Necesitarás una invitación para acceder a tu empresa.'
                              : 'Ingresa para continuar con tus proyectos.',
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 32),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => run(() => googleLogin()),
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continuar con Google'),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'o con tu correo',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),
                        TextFormField(
                          controller: email,
                          autofillHints: const [AutofillHints.email],
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (v) =>
                              v != null &&
                                  RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(v)
                              ? null
                              : 'Escribe un correo válido',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: password,
                          obscureText: !visible,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: visible
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              onPressed: () =>
                                  setState(() => visible = !visible),
                              icon: Icon(
                                visible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (v) => v != null && v.length >= 8
                              ? null
                              : 'Mínimo 8 caracteres',
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: busy
                                ? null
                                : () => run(() async {
                                    await FirebaseAuth.instance
                                        .sendPasswordResetEmail(
                                          email: email.text.trim(),
                                        );
                                    if (context.mounted) {
                                      toast(
                                        context,
                                        'Si la cuenta existe, recibirás un correo para recuperar el acceso.',
                                      );
                                    }
                                  }),
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                  if (!form.currentState!.validate()) return;
                                  if (register) {
                                    final result = await FirebaseAuth.instance
                                        .createUserWithEmailAndPassword(
                                          email: email.text.trim(),
                                          password: password.text,
                                        );
                                    await result.user!.sendEmailVerification();
                                  } else {
                                    await FirebaseAuth.instance
                                        .signInWithEmailAndPassword(
                                          email: email.text.trim(),
                                          password: password.text,
                                        );
                                  }
                                }),
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  register ? 'Crear cuenta' : 'Iniciar sesión',
                                ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => register = !register),
                          child: Text(
                            register
                                ? 'Ya tengo una cuenta'
                                : 'Tengo una invitación · Crear cuenta',
                          ),
                        ),
                        const SizedBox(height: 36),
                        const Text(
                          'Tu información, en el lugar correcto.\nEl acceso depende de los permisos asignados por DTS.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LoginFeature extends StatelessWidget {
  const _LoginFeature(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: gold, size: 20),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(color: Colors.white)),
    ],
  );
}
