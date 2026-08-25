import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/print_queue_repository.dart';
import '../../data/print_settings_store.dart';
import '../../domain/models/print_settings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../services/print_service.dart';
import '../../services/branding_marks.dart';
import '../../../../core/i18n/app_strings.dart';

/// الإعدادات المقروءة من القرص **قبل** إقلاع الواجهة.
///
/// تُحقن من `main()` عبر override. لماذا لا نقرأها كسولاً: أول طباعة كانت
/// تخرج بالإعدادات الافتراضية (طابعة خاطئة، مقاس خاطئ) لأن القراءة
/// غير متزامنة ولم تكن قد انتهت بعد.
final initialPrintSettingsProvider = Provider<PrintSettings>(
  (ref) => throw UnimplementedError(
    tr('initialPrintSettingsProvider يجب حقنه في ProviderScope من main()'),
  ),
);

class PrintSettingsNotifier extends Notifier<PrintSettings> {
  final PrintSettingsStore _store = PrintSettingsStore();

  @override
  PrintSettings build() => ref.watch(initialPrintSettingsProvider);

  Future<void> save(PrintSettings next) async {
    state = next;
    await _store.save(next);
  }

  Future<void> updateReceipt(ReceiptSettings r) =>
      save(state.copyWith(receipt: r));
  Future<void> updateTicket(TicketSettings t) =>
      save(state.copyWith(ticket: t));
  Future<void> updateOrderLabel(OrderLabelSettings o) =>
      save(state.copyWith(orderLabel: o));
}

final printSettingsProvider =
    NotifierProvider<PrintSettingsNotifier, PrintSettings>(
  PrintSettingsNotifier.new,
);

final printQueueRepositoryProvider = Provider<PrintQueueRepository?>((ref) {
  final storeId = ref.watch(storeIdProvider);
  if (storeId == null) return null;
  return PrintQueueRepository(ref.watch(firestoreProvider), storeId);
});

/// هوية المحل المشتركة بين الأجهزة كما تُطبع على الوصل.
final receiptBrandingProvider = Provider<ReceiptBranding>((ref) {
  final settings = ref.watch(storeSettingsProvider).value;
  return ReceiptBranding(
    facebook: settings?.facebookUrl ?? '',
    facebookName: settings?.facebookName ?? '',
    instagram: settings?.instagramUrl ?? '',
    instagramName: settings?.instagramName ?? '',
    website: settings?.storefrontUrl ?? '',
    logoBase64: settings?.logoBase64 ?? '',
  );
});

final printServiceProvider = Provider<PrintService>(
  (ref) => PrintService(
    settings: ref.watch(printSettingsProvider),
    queue: ref.watch(printQueueRepositoryProvider),
    branding: ref.watch(receiptBrandingProvider),
  ),
);
