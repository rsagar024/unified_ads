/// Google AdMob adapter for unified_ads.
///
/// Add this package next to `unified_ads`; the adapter registers itself and
/// only the Google Mobile Ads SDK (plus UMP) is linked into the app. Setup:
/// docs/setup/admob.md.
library;

export 'src/admob_adapter.dart' show AdmobAdapter;
export 'src/admob_consent_provider.dart'
    show AdmobConsentProvider, UmpDebugGeography;
