import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EpaycoCheckoutScreen extends StatefulWidget {
  const EpaycoCheckoutScreen({super.key, required this.checkoutUrl});

  final String checkoutUrl;

  @override
  State<EpaycoCheckoutScreen> createState() => _EpaycoCheckoutScreenState();
}

class _EpaycoCheckoutScreenState extends State<EpaycoCheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            if (request.url.contains('responseUrl') || request.url.contains('response_url')) {
              if (mounted) Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagar con Epayco'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmClose,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }

  Future<void> _confirmClose() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Deseas cancelar el pago?'),
        content: const Text(
          'Si no completaste el proceso tu saldo no ha cambiado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar pago'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar pago'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) Navigator.of(context).pop();
  }
}
