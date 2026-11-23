class SupabaseConfig {
  static const projectUrl = 'https://yudjodhkyjuxwqpamims.supabase.co';
  static const publishableKey = 'sb_publishable_AHFUiZs0S_Eg-_FpYweg8g_5p_DCiJO';

  static bool get isConfigured =>
      projectUrl.startsWith('https://') &&
      !projectUrl.contains('YOUR_PROJECT_ID') &&
      publishableKey.isNotEmpty &&
      publishableKey != 'YOUR_PUBLISHABLE_OR_ANON_KEY';
}
