import 'package:flutter/material.dart';

import '../theme/ocg_colors.dart';

/// Visor de fotos a pantalla completa con zoom.
/// Se abre al tocar cualquier foto de perfil.
class OcgPhotoViewer extends StatelessWidget {
  const OcgPhotoViewer({super.key});

  /// Abre el visor de fotos a pantalla completa.
  static Future<void> show(
    BuildContext context, {
    required String photoUrl,
    String? patientName,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar foto',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim1, anim2) {
        return _PhotoViewerPage(
          photoUrl: photoUrl,
          patientName: patientName,
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curve = Curves.easeOutCubic;
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: anim, curve: curve),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: curve),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError('Usa OcgPhotoViewer.show()');
  }
}

class _PhotoViewerPage extends StatefulWidget {
  const _PhotoViewerPage({required this.photoUrl, this.patientName});

  final String photoUrl;
  final String? patientName;

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // ── Photo centered ──
              Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        widget.photoUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            width: 80,
                            height: 80,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: OcgColors.bronze,
                                strokeWidth: 3,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, _) {
                          return Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: OcgColors.bronze.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    size: 48,
                                    color: OcgColors.bronze,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No se pudo cargar la foto',
                                    style: TextStyle(
                                      color: OcgColors.bronze,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // ── Top bar ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 8,
                      left: 16,
                      right: 16,
                      bottom: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        if (widget.patientName != null)
                          Expanded(
                            child: Text(
                              widget.patientName!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const Spacer(),
                        _CloseButton(),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom hint ──
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: const Center(
                    child: Text(
                      'Toca para cerrar · Pellizca para zoom',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      shape: const CircleBorder(),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Envuelve un avatar para que al tocarlo abra la foto en grande.
class OcgPhotoTapWrapper extends StatelessWidget {
  const OcgPhotoTapWrapper({
    super.key,
    required this.photoUrl,
    this.patientName,
    required this.child,
  });

  final String? photoUrl;
  final String? patientName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = photoUrl?.trim();
    if (cleanUrl == null || cleanUrl.isEmpty) return child;

    return GestureDetector(
      onTap: () {
        OcgPhotoViewer.show(
          context,
          photoUrl: cleanUrl,
          patientName: patientName,
        );
      },
      child: child,
    );
  }
}
