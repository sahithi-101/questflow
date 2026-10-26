// Public configuration only (spec 9: never expose the service-role key).
//
// Two ways to configure cloud mode:
//   1. Edit [manualUrl] / [manualAnonKey] below (fine for local coursework),
//   2. or pass --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
// Dart-defines win when both are set.
//
// Where to find the values: Supabase dashboard → your project →
// Settings → API → "Project URL" and "anon public" key.

const String manualUrl = 'https://siziymjpshgipravyrbp.supabase.co';      // e.g. 'https://abcdefgh.supabase.co'
const String manualAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNpeml5bWpwc2hnaXByYXZ5cmJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwMDgxMDYsImV4cCI6MjEwODU4NDEwNn0.Hw_zBh-Bgn9D_UQt3_fZXKMbHa5NF6D2F6mcCFuncu4';  // e.g. 'eyJhbGciOi...'

const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: manualUrl,
);
const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: manualAnonKey,
);

bool get cloudConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
