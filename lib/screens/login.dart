import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../services/auth_service.dart';
import '../services/moderation_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/moderation_notice.dart';
import 'home_page.dart';
import 'onboarding_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _completeSignIn(User user) async {
    final profile = await UserService.instance.ensureUserDocument(user);
    if (!mounted) return;

    appStore.user.nickname = profile.nickname;
    appStore.user.points = profile.points;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => profile.onboardingCompleted
            ? const HomePage()
            : const OnboardingPage(),
      ),
    );
  }

  Future<void> _handleEmailLogin() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack('이메일과 비밀번호를 모두 입력해 주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await AuthService.instance.signInWithEmail(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) return;
      await _completeSignIn(user);
    } on FirebaseAuthException catch (e) {
      _showSnack(AuthService.instance.getErrorMessage(e));
    } catch (e) {
      _showSnack('로그인 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSocialLogin(
    Future<UserCredential?> Function() signInMethod,
    String providerName,
  ) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final credential = await signInMethod();
      final user = credential?.user;
      if (user == null) return;
      await _completeSignIn(user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }
      _showSnack(
        '$providerName 로그인 오류: ${AuthService.instance.getErrorMessage(e)}',
      );
    } catch (e) {
      _showSnack('$providerName 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final resetController =
        TextEditingController(text: _emailController.text.trim());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('비밀번호 재설정'),
        content: TextField(
          controller: resetController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: '가입한 이메일 주소 입력',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('메일 보내기'),
          ),
        ],
      ),
    );

    final email = resetController.text.trim();
    resetController.dispose();

    if (confirmed != true || email.isEmpty) return;

    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      _showSnack('비밀번호 재설정 메일을 보냈습니다. 메일함을 확인해 주세요.');
    } on FirebaseAuthException catch (e) {
      _showSnack(AuthService.instance.getErrorMessage(e));
    } catch (e) {
      _showSnack('메일 전송에 실패했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              children: [
                const Center(child: HammerAnimation()),
                const SizedBox(height: 15),
                const Text(
                  '겜문철',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  '게임의 순간을 공정하게 판정하다',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 30),
                const Text(
                  '로그인',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  key: const Key('login-id'),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: '이메일 주소',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _handleEmailLogin(),
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _showPasswordResetDialog,
                    child: const Text('비밀번호를 잊으셨나요?'),
                  ),
                ),
                FilledButton(
                  onPressed: _isLoading ? null : _handleEmailLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: Text(_isLoading ? '로그인 중...' : '로그인'),
                ),
                const SizedBox(height: 23),
                const _DividerLabel('또는'),
                const SizedBox(height: 18),
                SocialLoginButton(
                  label: _isLoading ? '로그인 중...' : 'Google로 계속하기',
                  leading: const _GoogleMark(),
                  onPressed: _isLoading
                      ? null
                      : () => _handleSocialLogin(
                            AuthService.instance.signInWithGoogle,
                            'Google',
                          ),
                ),
                const SizedBox(height: 10),
                SocialLoginButton(
                  label: 'Apple로 계속하기',
                  leading:
                      const Icon(Icons.apple, color: Colors.white, size: 23),
                  onPressed: _isLoading
                      ? null
                      : () => _handleSocialLogin(
                            AuthService.instance.signInWithApple,
                            'Apple',
                          ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '아직 계정이 없으신가요?',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignUpPage(),
                                ),
                              ),
                      child: const Text('회원가입'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSignUp() async {
    if (_isLoading) return;
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (nickname.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack('닉네임, 이메일, 비밀번호를 모두 입력해 주세요.');
      return;
    }
    if (password.length < 6) {
      _showSnack('비밀번호는 6자 이상으로 입력해 주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final modResult = await ModerationService.instance.check(
        nickname,
        context: ModerationContext.nickname,
      );
      if (!mounted || !await handleModeration(context, modResult)) return;

      final credential = await AuthService.instance.signUpWithEmail(
        email: email,
        password: password,
        nickname: nickname,
      );
      final user = credential.user;
      if (user != null) {
        await UserService.instance.ensureUserDocument(
          user,
          preferredNickname: nickname,
        );
      }
      if (!mounted) return;

      appStore.user.nickname = nickname;
      appStore.user.points = 0;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(AuthService.instance.getErrorMessage(e));
    } catch (e) {
      _showSnack('회원가입 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '겜문철과 함께\n공정한 판정을 시작하세요.',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 26),
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              hintText: '닉네임',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: '이메일 주소',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: '비밀번호 (6자 이상)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _handleSignUp,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(54),
            ),
            child: Text(_isLoading ? '가입 처리 중...' : '회원가입 완료'),
          ),
        ],
      ),
    );
  }
}

class HammerAnimation extends StatefulWidget {
  const HammerAnimation({super.key});

  @override
  State<HammerAnimation> createState() => _HammerAnimationState();
}

class _HammerAnimationState extends State<HammerAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _angle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    )..repeat();

    _angle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.58, end: 0.58), weight: 24),
      TweenSequenceItem(
        tween: Tween(begin: 0.58, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 16,
      ),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 8),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.58)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 20,
      ),
      TweenSequenceItem(tween: Tween(begin: 0.58, end: 0.58), weight: 32),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 154,
      width: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 22,
            child: Container(
              width: 116,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.32),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            top: 46,
            left: 42,
            child: AnimatedBuilder(
              animation: _angle,
              builder: (_, child) => Transform.rotate(
                angle: _angle.value,
                alignment: const Alignment(0.73, -0.07),
                child: child,
              ),
              child: const CustomPaint(
                size: Size(120, 90),
                painter: _GavelPainter(color: AppColors.lavender),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GavelPainter extends CustomPainter {
  const _GavelPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(36, 36, 110, 48),
        const Radius.circular(6),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(32, 42), width: 26, height: 24),
        const Radius.circular(4),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(32, 20), width: 30, height: 12),
        const Radius.circular(5),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(32, 64), width: 30, height: 12),
        const Radius.circular(5),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GavelPainter oldDelegate) =>
      oldDelegate.color != color;
}

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onPressed,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.line),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.centerLeft, child: leading),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 23,
      height: 23,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }
}