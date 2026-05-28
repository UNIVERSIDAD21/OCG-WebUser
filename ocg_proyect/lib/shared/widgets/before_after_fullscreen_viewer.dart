import 'package:flutter/material.dart';
import '../theme/ocg_colors.dart';
import '../widgets/before_after_slider.dart';

/// Slider de comparación Antes/Después con botón de pantalla completa
/// y diálogo con zoom interactivo (lock/unlock).
///
/// Usado tanto por admin (simulator_screen) como por paciente
/// (patient_simulations_screen).
class BeforeAfterFullscreenViewer extends StatefulWidget {
  const BeforeAfterFullscreenViewer({
    super.key,
    required this.beforeUrl,
    required this.afterUrl,
    this.height,
    this.compact = false,
  });

  final String beforeUrl;
  final String afterUrl;
  final double? height;
  final bool compact;

  @override
  State<BeforeAfterFullscreenViewer> createState() =>
      _BeforeAfterFullscreenViewerState();
}

class _BeforeAfterFullscreenViewerState
    extends State<BeforeAfterFullscreenViewer> {
  Future<void> _openFullscreen(
    BuildContext context,
    String beforeUrl,
    String afterUrl,
  ) async {
    final screenHeight = MediaQuery.of(context).size.height;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (ctx) => _FullscreenComparisonDialog(
        beforeUrl: beforeUrl,
        afterUrl: afterUrl,
        screenHeight: screenHeight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalHeight = widget.height ??
        (MediaQuery.of(context).size.height * 0.4).clamp(280.0, 500.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OcgColors.bronze.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: OcgColors.espresso.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                color: OcgColors.bronze,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Comparación Antes / Después',
                  style: TextStyle(
                    color: OcgColors.espresso,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (widget.compact)
                IconButton.filledTonal(
                  onPressed: () =>
                      _openFullscreen(context, widget.beforeUrl, widget.afterUrl),
                  icon: const Icon(Icons.open_in_full, size: 18),
                  tooltip: 'Pantalla completa',
                )
              else
                TextButton.icon(
                  onPressed: () =>
                      _openFullscreen(context, widget.beforeUrl, widget.afterUrl),
                  icon: const Icon(Icons.open_in_full, size: 18),
                  label: const Text('Pantalla completa'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            child: Stack(
              children: [
                BeforeAfterSlider(
                  height: normalHeight,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  before: _SimulationImage(
                    url: widget.beforeUrl,
                    height: normalHeight,
                  ),
                  after: _SimulationImage(
                    url: widget.afterUrl,
                    height: normalHeight,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  child: _labelChip('Antes', OcgColors.bronze),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: _labelChip('Después', OcgColors.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Diálogo de pantalla completa ──────────────────────────

class _FullscreenComparisonDialog extends StatefulWidget {
  const _FullscreenComparisonDialog({
    required this.beforeUrl,
    required this.afterUrl,
    required this.screenHeight,
  });

  final String beforeUrl;
  final String afterUrl;
  final double screenHeight;

  @override
  State<_FullscreenComparisonDialog> createState() =>
      _FullscreenComparisonDialogState();
}

class _FullscreenComparisonDialogState
    extends State<_FullscreenComparisonDialog> {
  bool _isLocked = false;

  @override
  Widget build(BuildContext context) {
    final dialogHeight = widget.screenHeight.clamp(400.0, 1000.0);

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: const Color(0xFF17120E),
      child: SafeArea(
        child: SizedBox(
          height: dialogHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Comparación Antes / Después',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _isLocked = !_isLocked),
                      icon: Icon(
                        _isLocked ? Icons.lock : Icons.lock_open,
                        color: _isLocked ? OcgColors.warning : Colors.white70,
                      ),
                      tooltip: _isLocked
                          ? 'Desbloquear (slider)'
                          : 'Bloquear (zoom libre)',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildComparisonView(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _isLocked
                      ? '🔒 Zoom libre independiente en cada imagen'
                      : 'Desliza para comparar  •  🔒 Bloquea para hacer zoom',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sliderHeight = constraints.maxHeight;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 26,
                offset: Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              BeforeAfterSlider(
                height: sliderHeight,
                locked: _isLocked,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                before: _isLocked
                    ? InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 8.0,
                        child: _SimulationImage(
                          url: widget.beforeUrl,
                          height: sliderHeight,
                        ),
                      )
                    : _SimulationImage(
                        url: widget.beforeUrl,
                        height: sliderHeight,
                      ),
                after: _isLocked
                    ? InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 8.0,
                        child: _SimulationImage(
                          url: widget.afterUrl,
                          height: sliderHeight,
                        ),
                      )
                    : _SimulationImage(
                        url: widget.afterUrl,
                        height: sliderHeight,
                      ),
              ),
              Positioned(
                top: 10,
                left: 12,
                child: _labelChip('Antes', OcgColors.bronze),
              ),
              Positioned(
                top: 10,
                right: 12,
                child: _labelChip('Después', OcgColors.success),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ── Helpers ───────────────────────────────────────────────

Widget _labelChip(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color, width: 1.5),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    ),
  );
}

class _SimulationImage extends StatelessWidget {
  const _SimulationImage({
    required this.url,
    required this.height,
  });

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0E0B08),
      child: Image.network(
        url,
        width: double.infinity,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final total = loadingProgress.expectedTotalBytes;
          final progress = total == null
              ? null
              : loadingProgress.cumulativeBytesLoaded / total;
          return Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2.4,
                color: OcgColors.bronze,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => SizedBox(
          height: height,
          child: const Center(child: Text('No se pudo cargar la imagen.')),
        ),
      ),
    );
  }
}
