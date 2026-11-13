import 'package:flutter/material.dart';

/// PillAI's semantic color palette.
///
/// Calm teal for care and "taken", indigo reserved for anything AI, amber for
/// "due now", and red only for missed doses and emergencies. Keeping each hue
/// to one meaning is what lets screens stay quiet and still readable.
abstract final class AppColors {
  static const Color canvas = Color(0xFFF6F5F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEFEEE7);

  static const Color ink = Color(0xFF13201E);
  static const Color inkMuted = Color(0xFF56625F);
  static const Color inkSubtle = Color(0xFF8D9794);

  static const Color primary = Color(0xFF0A7A65);
  static const Color primaryDark = Color(0xFF065A4A);
  static const Color primarySoft = Color(0xFFDCF0E9);
  static const Color primaryFaint = Color(0xFFEEF7F3);

  static const Color ai = Color(0xFF5B4FD0);
  static const Color aiSoft = Color(0xFFECE9FC);

  static const Color amber = Color(0xFFB56A00);
  static const Color amberSoft = Color(0xFFFCEFD8);
  static const Color danger = Color(0xFFC73B3B);
  static const Color dangerSoft = Color(0xFFFBE6E4);

  static const Color border = Color(0xFFE4E2D9);
  static const Color divider = Color(0xFFECEAE2);
  static const Color disabled = Color(0xFFC2C7C4);

  // Names kept for widgets that predate the redesign.
  static const Color navy = ink;
  static const Color navyMuted = inkMuted;
  static const Color mint = primary;
  static const Color mintBright = Color(0xFF2FBF8F);
  static const Color mintSoft = primarySoft;
  static const Color warning = amber;
  static const Color warningSoft = amberSoft;
  static const Color lavender = ai;
  static const Color lavenderSoft = aiSoft;

  /// Accent per medicine so a pill keeps its color everywhere it appears.
  static const List<Color> medicine = <Color>[
    Color(0xFF0A7A65),
    Color(0xFF5B4FD0),
    Color(0xFFC77A0A),
    Color(0xFFC2456E),
    Color(0xFF2B7BB9),
  ];

  static Color medicineColor(int seed) => medicine[seed % medicine.length];
}

abstract final class AppGradients {
  static const LinearGradient hero = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: <Color>[Color(0xFF0A7A65), Color(0xFF0C5C6C)],
  );

  static const LinearGradient ai = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: <Color>[Color(0xFF0A7A65), Color(0xFF5B4FD0)],
  );
}

/// Spacing tokens based on a four-point grid.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
}

abstract final class AppRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

abstract final class AppDurations {
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration regular = Duration(milliseconds: 240);
}

abstract final class AppShadows {
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0A13201E), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(color: Color(0x2E0A7A65), blurRadius: 28, offset: Offset(0, 12)),
  ];
}

@immutable
class AppLayoutTokens extends ThemeExtension<AppLayoutTokens> {
  const AppLayoutTokens({
    required this.isSimple,
    required this.minTapTarget,
    required this.primaryActionHeight,
    required this.rowMinHeight,
    required this.iconSize,
  });

  static const standard = AppLayoutTokens(
    isSimple: false,
    minTapTarget: 48,
    primaryActionHeight: 54,
    rowMinHeight: 64,
    iconSize: 22,
  );

  static const simple = AppLayoutTokens(
    isSimple: true,
    minTapTarget: 60,
    primaryActionHeight: 64,
    rowMinHeight: 78,
    iconSize: 28,
  );

  final bool isSimple;
  final double minTapTarget;
  final double primaryActionHeight;
  final double rowMinHeight;
  final double iconSize;

  static AppLayoutTokens of(BuildContext context) {
    return Theme.of(context).extension<AppLayoutTokens>() ?? standard;
  }

  @override
  AppLayoutTokens copyWith({
    bool? isSimple,
    double? minTapTarget,
    double? primaryActionHeight,
    double? rowMinHeight,
    double? iconSize,
  }) {
    return AppLayoutTokens(
      isSimple: isSimple ?? this.isSimple,
      minTapTarget: minTapTarget ?? this.minTapTarget,
      primaryActionHeight: primaryActionHeight ?? this.primaryActionHeight,
      rowMinHeight: rowMinHeight ?? this.rowMinHeight,
      iconSize: iconSize ?? this.iconSize,
    );
  }

  @override
  AppLayoutTokens lerp(covariant AppLayoutTokens? other, double t) {
    if (other == null) return this;
    return AppLayoutTokens(
      isSimple: t < .5 ? isSimple : other.isSimple,
      minTapTarget: minTapTarget + (other.minTapTarget - minTapTarget) * t,
      primaryActionHeight:
          primaryActionHeight +
          (other.primaryActionHeight - primaryActionHeight) * t,
      rowMinHeight: rowMinHeight + (other.rowMinHeight - rowMinHeight) * t,
      iconSize: iconSize + (other.iconSize - iconSize) * t,
    );
  }
}

/// The app-level Material theme.
///
/// [build] is the single source; [lightTheme] and [simpleTheme] remain for
/// call sites that do not care about script direction.
abstract final class AppTheme {
  static ThemeData get light => lightTheme;
  static ThemeData get lightTheme => build();
  static ThemeData get simpleTheme => build(simple: true);

  static ThemeData build({bool simple = false, bool arabic = false}) {
    final double scale = simple ? 1.16 : 1;
    // Tracking breaks Arabic letter joining, so only Latin headings get it.
    final double tightTracking = arabic ? 0 : -0.4;

    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.ai,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.aiSoft,
          onSecondaryContainer: AppColors.ink,
          tertiary: AppColors.amber,
          onTertiary: Colors.white,
          tertiaryContainer: AppColors.amberSoft,
          onTertiaryContainer: AppColors.ink,
          error: AppColors.danger,
          onError: Colors.white,
          errorContainer: AppColors.dangerSoft,
          onErrorContainer: AppColors.ink,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.inkMuted,
          surfaceContainerLowest: AppColors.surface,
          surfaceContainerLow: AppColors.canvas,
          surfaceContainer: AppColors.surfaceMuted,
          surfaceContainerHigh: AppColors.surfaceMuted,
          surfaceContainerHighest: AppColors.border,
          outline: AppColors.border,
          outlineVariant: AppColors.divider,
        );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      visualDensity: simple
          ? VisualDensity.comfortable
          : VisualDensity.standard,
      // Prefer modern Arabic faces where the platform has them; unknown
      // names are skipped and the system fallback still applies.
      fontFamilyFallback: const [
        'Noto Sans Arabic',
        'SF Arabic',
        'Segoe UI',
        'Tahoma',
      ],
    );

    TextStyle? style(
      TextStyle? source,
      double size, {
      FontWeight weight = FontWeight.w400,
      Color color = AppColors.ink,
      double height = 1.4,
      double letterSpacing = 0,
    }) {
      return source?.copyWith(
        fontSize: size * scale,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    final TextTheme source = base.textTheme;
    final TextTheme textTheme = source.copyWith(
      displaySmall: style(
        source.displaySmall,
        34,
        weight: FontWeight.w800,
        height: 1.15,
        letterSpacing: tightTracking * 2,
      ),
      headlineLarge: style(
        source.headlineLarge,
        28,
        weight: FontWeight.w800,
        height: 1.2,
        letterSpacing: tightTracking * 1.5,
      ),
      headlineMedium: style(
        source.headlineMedium,
        24,
        weight: FontWeight.w700,
        height: 1.25,
        letterSpacing: tightTracking,
      ),
      headlineSmall: style(
        source.headlineSmall,
        20,
        weight: FontWeight.w700,
        height: 1.3,
        letterSpacing: tightTracking / 2,
      ),
      titleLarge: style(source.titleLarge, 18, weight: FontWeight.w700),
      titleMedium: style(source.titleMedium, 16, weight: FontWeight.w600),
      titleSmall: style(source.titleSmall, 14, weight: FontWeight.w600),
      bodyLarge: style(source.bodyLarge, 16, height: 1.5),
      bodyMedium: style(
        source.bodyMedium,
        14,
        color: AppColors.inkMuted,
        height: 1.45,
      ),
      bodySmall: style(
        source.bodySmall,
        12.5,
        color: AppColors.inkSubtle,
        height: 1.4,
      ),
      labelLarge: style(
        source.labelLarge,
        15,
        weight: FontWeight.w600,
        height: 1.2,
      ),
      labelMedium: style(
        source.labelMedium,
        13,
        weight: FontWeight.w600,
        color: AppColors.inkMuted,
        height: 1.2,
      ),
      labelSmall: style(
        source.labelSmall,
        11.5,
        weight: FontWeight.w600,
        color: AppColors.inkSubtle,
        height: 1.2,
      ),
    );

    final double buttonHeight = simple ? 62 : 54;
    const BorderRadius controlRadius = BorderRadius.all(
      Radius.circular(AppRadii.md),
    );
    const BorderRadius inputRadius = BorderRadius.all(
      Radius.circular(AppRadii.md),
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        simple ? AppLayoutTokens.simple : AppLayoutTokens.standard,
      ],
      textTheme: textTheme,
      appBarTheme: AppBarThemeData(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        titleTextStyle: textTheme.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        space: 1,
        thickness: 1,
      ),
      iconTheme: IconThemeData(color: AppColors.inkMuted, size: 22 * scale),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.inkMuted,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium,
        minVerticalPadding: simple ? 14 : 10,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: simple ? 18 : 15,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.inkSubtle),
        labelStyle: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        border: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.inkSubtle,
          minimumSize: Size(48, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: Size(48, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: const BorderSide(color: AppColors.border, width: 1.2),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: Size(48, simple ? 56 : 44),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size.square(simple ? 56 : 44),
          iconSize: simple ? 28 : 24,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySoft,
        disabledColor: AppColors.surfaceMuted,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: simple ? 10 : 6,
        ),
        labelStyle: textTheme.labelLarge?.copyWith(color: AppColors.ink),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.primaryDark,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: simple ? 86 : 72,
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primaryDark : AppColors.inkSubtle,
            size: simple ? 30 : 25,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return (textTheme.labelMedium ?? const TextStyle()).copyWith(
            color: selected ? AppColors.primaryDark : AppColors.inkSubtle,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.inkSubtle,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.border,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
        shape: CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppColors.mintBright,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.sm)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
        circularTrackColor: AppColors.primarySoft,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.disabled,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: AppColors.surface,
      ),
    );
  }
}
