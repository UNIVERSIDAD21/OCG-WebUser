import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/payments/data/models/payment_model.dart';

void main() {
  group('PaymentModel serialization', () {
    test('serialización completa con todos los campos', () {
      final createdAt = DateTime(2026, 3, 17, 10, 0);
      final updatedAt = DateTime(2026, 3, 17, 11, 0);
      final fechaProximoPago = DateTime(2026, 3, 25, 9, 0);

      final model = PaymentModel(
        id: 'p1',
        patientId: 'p1',
        totalTratamiento: 1500000,
        montoPagado: 800000,
        saldoPendiente: 700000,
        fechaProximoPago: fechaProximoPago,
        estado: PaymentStatus.pendiente,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final json = model.toJson();

      expect(json['id'], 'p1');
      expect(json['patientId'], 'p1');
      expect(json['totalTratamiento'], 1500000);
      expect(json['montoPagado'], 800000);
      expect(json['saldoPendiente'], 700000);
      expect(json['fechaProximoPago'], isA<Timestamp>());
      expect(json['estado'], PaymentStatus.pendiente.name);
      expect(json['createdAt'], isA<Timestamp>());
      expect(json['updatedAt'], isA<Timestamp>());
    });

    test('serialización con fechaProximoPago nulo', () {
      final model = PaymentModel(
        id: 'p2',
        patientId: 'p2',
        totalTratamiento: 1000,
        montoPagado: 100,
        saldoPendiente: 900,
        fechaProximoPago: null,
        estado: PaymentStatus.pendiente,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 2),
      );

      final json = model.toJson();
      expect(json['fechaProximoPago'], isNull);
    });

    test('roundtrip toJson/fromJson conserva valores', () {
      final original = PaymentModel(
        id: 'p3',
        patientId: 'p3',
        totalTratamiento: 2000000,
        montoPagado: 1200000,
        saldoPendiente: 800000,
        fechaProximoPago: DateTime(2026, 4, 1, 8, 30),
        estado: PaymentStatus.alDia,
        createdAt: DateTime(2026, 3, 17, 8, 0),
        updatedAt: DateTime(2026, 3, 17, 9, 0),
      );

      final restored = PaymentModel.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.patientId, original.patientId);
      expect(restored.totalTratamiento, original.totalTratamiento);
      expect(restored.montoPagado, original.montoPagado);
      expect(restored.saldoPendiente, original.saldoPendiente);
      expect(restored.fechaProximoPago, original.fechaProximoPago);
      expect(restored.estado, original.estado);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });
  });

  group('PaymentModel.calcularEstado', () {
    final now = DateTime(2026, 3, 17, 12, 0);

    test('pagadoTotal cuando saldo <= 0', () {
      final status = PaymentModel.calcularEstado(
        saldoPendiente: 0,
        fechaProximoPago: now.add(const Duration(days: 2)),
        now: now,
      );
      expect(status, PaymentStatus.pagadoTotal);
    });

    test('pendiente cuando saldo > 0 y no hay fechaProximoPago', () {
      final status = PaymentModel.calcularEstado(
        saldoPendiente: 100,
        fechaProximoPago: null,
        now: now,
      );
      expect(status, PaymentStatus.pendiente);
    });

    test('vencido cuando fechaProximoPago ya pasó', () {
      final status = PaymentModel.calcularEstado(
        saldoPendiente: 100,
        fechaProximoPago: now.subtract(const Duration(hours: 1)),
        now: now,
      );
      expect(status, PaymentStatus.vencido);
    });

    test('pendiente cuando fechaProximoPago está dentro de los próximos 7 días', () {
      final status = PaymentModel.calcularEstado(
        saldoPendiente: 100,
        fechaProximoPago: now.add(const Duration(days: 3)),
        now: now,
      );
      expect(status, PaymentStatus.pendiente);
    });

    test('alDia cuando fechaProximoPago está después de 7 días', () {
      final status = PaymentModel.calcularEstado(
        saldoPendiente: 100,
        fechaProximoPago: now.add(const Duration(days: 10)),
        now: now,
      );
      expect(status, PaymentStatus.alDia);
    });
  });

  group('PaymentTransaction serialization', () {
    test('serialización completa incluyendo campos de PayU', () {
      final tx = PaymentTransaction(
        id: 'tx-1',
        monto: 350000,
        fecha: DateTime(2026, 3, 17, 14, 30),
        metodo: PaymentMethod.payu,
        referencia: 'REF-001',
        registradoPor: 'payu_webhook',
        notas: 'Pago aprobado',
        reciboUrl: 'https://example.com/recibo.pdf',
        payuOrderId: 'ORDER-123',
        payuTransactionId: 'TX-PAYU-999',
      );

      final json = tx.toJson();
      expect(json['id'], 'tx-1');
      expect(json['monto'], 350000);
      expect(json['fecha'], isA<Timestamp>());
      expect(json['metodo'], PaymentMethod.payu.name);
      expect(json['referencia'], 'REF-001');
      expect(json['registradoPor'], 'payu_webhook');
      expect(json['notas'], 'Pago aprobado');
      expect(json['reciboUrl'], 'https://example.com/recibo.pdf');
      expect(json['payuOrderId'], 'ORDER-123');
      expect(json['payuTransactionId'], 'TX-PAYU-999');

      final restored = PaymentTransaction.fromJson(json);
      expect(restored.id, tx.id);
      expect(restored.monto, tx.monto);
      expect(restored.fecha, tx.fecha);
      expect(restored.metodo, tx.metodo);
      expect(restored.referencia, tx.referencia);
      expect(restored.registradoPor, tx.registradoPor);
      expect(restored.notas, tx.notas);
      expect(restored.reciboUrl, tx.reciboUrl);
      expect(restored.payuOrderId, tx.payuOrderId);
      expect(restored.payuTransactionId, tx.payuTransactionId);
    });
  });
}
