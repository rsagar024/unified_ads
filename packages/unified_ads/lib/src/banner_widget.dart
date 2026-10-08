import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'banner_ad.dart';

/// Builds the platform view for a banner attempt.
typedef BannerPlatformViewBuilder =
    Widget Function(BuildContext context, BannerAttempt attempt);

/// Displays a [BannerAd] and starts loading it when first laid out.
///
/// The widget does not dispose the ad; the owner calls `BannerAd.dispose`.
///
/// ```dart
/// final banner = BannerAd(size: const BannerSize.adaptiveAnchored());
/// // ...
/// UnifiedBannerWidget(ad: banner, anchored: true)
/// ```
class UnifiedBannerWidget extends StatefulWidget {
  /// Creates the widget.
  const UnifiedBannerWidget({
    required this.ad,
    super.key,
    this.anchored = false,
    this.placeholder,
    this.collapseWhenFailed = true,
  });

  /// The banner to display.
  final BannerAd ad;

  /// Whether the banner is anchored at the screen edge; adds bottom safe-area
  /// padding.
  final bool anchored;

  /// Shown while no native view exists yet.
  final Widget? placeholder;

  /// Whether to take no space when every network failed.
  final bool collapseWhenFailed;

  /// Builds the native view. Replaced in widget tests.
  @visibleForTesting
  static BannerPlatformViewBuilder platformViewBuilder =
      buildBannerPlatformView;

  @override
  State<UnifiedBannerWidget> createState() => _UnifiedBannerWidgetState();
}

class _UnifiedBannerWidgetState extends State<UnifiedBannerWidget> {
  @override
  void initState() {
    super.initState();
    widget.ad.addListener(_onAdChanged);
  }

  @override
  void didUpdateWidget(UnifiedBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.ad, widget.ad)) {
      oldWidget.ad.removeListener(_onAdChanged);
      widget.ad.addListener(_onAdChanged);
    }
  }

  @override
  void dispose() {
    if (widget.ad.state != BannerAdState.disposed) {
      widget.ad.removeListener(_onAdChanged);
    }
    super.dispose();
  }

  void _onAdChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ad = widget.ad;
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        if (ad.state == BannerAdState.idle) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && ad.state == BannerAdState.idle) {
              unawaited(ad.load(width: availableWidth));
            }
          });
        }
        if (ad.state == BannerAdState.disposed ||
            (ad.state == BannerAdState.failed && widget.collapseWhenFailed)) {
          return const SizedBox.shrink();
        }

        final requested = ad.size.withWidth(availableWidth);
        final width = ad.adSize?.width ?? requested.width ?? availableWidth;
        final height = ad.adSize?.height ?? requested.fallbackHeight;
        final attempt = ad.current;
        final child = attempt == null
            ? widget.placeholder ?? const SizedBox.shrink()
            : KeyedSubtree(
                key: ValueKey(attempt.adId),
                child: UnifiedBannerWidget.platformViewBuilder(
                  context,
                  attempt,
                ),
              );

        Widget result = Center(
          child: SizedBox(width: width, height: height, child: child),
        );
        if (widget.anchored) result = SafeArea(top: false, child: result);
        return result;
      },
    );
  }
}

/// Default [BannerPlatformViewBuilder]: Hybrid Composition on Android and
/// `UiKitView` on iOS, with no gesture recognizers so taps reach the native
/// ad view.
Widget buildBannerPlatformView(BuildContext context, BannerAttempt attempt) {
  const codec = StandardMessageCodec();
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
      return PlatformViewLink(
        viewType: attempt.viewType,
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const {},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        ),
        onCreatePlatformView: (params) {
          final controller = PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: attempt.viewType,
            layoutDirection: direction,
            creationParams: attempt.creationParams,
            creationParamsCodec: codec,
            onFocus: () => params.onFocusChanged(true),
          );
          controller.addOnPlatformViewCreatedListener(
            params.onPlatformViewCreated,
          );
          unawaited(controller.create());
          return controller;
        },
      );
    case TargetPlatform.iOS:
      return UiKitView(
        viewType: attempt.viewType,
        creationParams: attempt.creationParams,
        creationParamsCodec: codec,
        gestureRecognizers: const {},
      );
    case TargetPlatform.fuchsia ||
        TargetPlatform.linux ||
        TargetPlatform.macOS ||
        TargetPlatform.windows:
      return const SizedBox.shrink();
  }
}
