import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/scanner_service.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../inventory/domain/models/product.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../../sales/domain/models/sale.dart';
import '../../../settings/domain/models/store_settings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/cart_sync_service.dart';
import '../../domain/models/reservation.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_providers.dart';
import '../widgets/cart_panel.dart';
import '../widgets/pos_dialogs.dart';
import '../widgets/product_grid.dart';
import '../../../../core/i18n/app_strings.dart';

/// عتبة التخطيط العريض.
///
/// ⚠️ **القرار بالعرض وحده — أبداً لا بالارتفاع.** فتح لوحة المفاتيح على
/// الهاتف يُنقص الارتفاع، فلو بنينا القرار عليه لتبدّلت شجرة الـ widgets
/// عند كل كتابة، وارتجفت الشاشة، **واختفى زرّ الدفع** (عطل حقيقي حدث).
const double _wideLayoutBreakpoint = 900;

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  String _query = '';
  bool _processing = false;
  bool _cameraOpen = false;

  /// المنتجات المطابقة لآخر بحث بالباركود — تُعرض في الشبكة عند تعدّدها.
  List<Product>? _barcodeMatches;

  /// فرز الشبكة حسب نوع المنتج. `null` = كل الأنواع.
  String? _category;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// إعادة التركيز إلى حقل الباركود — القارئ السلكي يكتب فيه ثم يضغط Enter.
  /// بلا هذا يضيع أول رمز يُمسح بعد كل عملية.
  void _refocusSearch() {
    if (!_isDesktop || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _barcodeMatches = null;
    });
    _refocusSearch();
  }

  // ───────────────────────── البحث والإضافة ─────────────────────────

  /// بحث بالباركود أولاً (مطابقة تامة على الخادم) ثم بالاسم محلياً.
  Future<void> _submitSearch(String raw) async {
    // الماسحات تُلحق أسطراً ومحارف تحكّم خفية تُفشل المطابقة التامة بصمت.
    final code = cleanBarcode(raw);
    if (code.isEmpty) return;

    final repo = ref.read(inventoryRepositoryProvider);
    final inventory = ref.read(inventoryProvider);

    // 1) مطابقة تامة للباركود.
    Product? exact;
    try {
      exact = await repo?.findByBarcode(code);
    } catch (_) {
      // بلا إنترنت: نكمل بالبحث المحلّي في المخزون المخزَّن.
    }
    exact ??= inventory.where((p) => p.barcode == code).firstOrNull;

    if (exact != null) {
      _addToCart(exact);
      return;
    }

    // 2) بحث بالاسم أو جزء الباركود في القائمة المحمّلة.
    final matches = inventory.where((p) => p.matches(raw)).toList();

    if (matches.length == 1) {
      _addToCart(matches.first);
      return;
    }

    if (matches.isEmpty) {
      // ⚠️ نعرض **الرقم المقروء فعلاً**: يكشف فوراً إن كان الخلل في القراءة
      // (محارف زائدة، قارئ يقرأ نصف الرمز) لا في المخزون.
      if (mounted) {
        showErr(context, trf('لا يوجد منتج بالباركود «{0}»', [code]));
        _refocusSearch();
      }
      return;
    }

    setState(() => _barcodeMatches = matches);
    if (mounted) {
      showInfo(context, trf('{0} منتجات مطابقة — اختر من القائمة', [matches.length]));
    }
  }

  void _addToCart(Product product) {
    if (product.availableQuantity <= 0) {
      showInfo(context, trf('«{0}» نفد من المخزون — أُضيف رغم ذلك', [product.name]));
    }
    ref.read(cartProvider.notifier).add(product);
    // تفريغ حقل البحث وإعادة التركيز: نصّ باقٍ في الحقل يبتلع اختصارات
    // لوحة المفاتيح (Enter و Space) فلا يعمل البيع السريع.
    _clearSearch();
  }

  Future<void> _scanContinuous() async {
    setState(() => _cameraOpen = true);
    try {
      await ScannerService.scanContinuous(context, (code) async {
        await _submitSearch(code);
      });
    } finally {
      if (mounted) setState(() => _cameraOpen = false);
      _refocusSearch();
    }
  }

  // ───────────────────────── اختصارات لوحة المفاتيح ─────────────────────────

  /// يلتقط المفاتيح التي لم يستهلكها العنصر المركَّز.
  ///
  /// موضعه في **Focus جدّ يلفّ الشاشة كلها** (`canRequestFocus: false`,
  /// `skipTraversal: true`): أي مفتاح يصعد إليه مهما كان التركيز — وحتى
  /// دون لمس الفأرة إطلاقاً بعد فتح الشاشة.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!_isDesktop) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      _clearSearch();
      return KeyEventResult.handled;
    }

    final cart = ref.read(cartProvider);
    final searchHasText = _searchCtrl.text.trim().isNotEmpty;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      // الاستثناء الوحيد: حقل البحث فيه نص ⇒ Enter للبحث (القارئ السلكي).
      if (searchHasText) return KeyEventResult.ignored;
      if (!_canQuickSell(cart)) return KeyEventResult.ignored;
      unawaited(_quickSell(print: false));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.space) {
      // مسافة داخل نصّ بحث = مسافة عادية.
      if (searchHasText) return KeyEventResult.ignored;
      if (!_canQuickSell(cart)) return KeyEventResult.ignored;
      unawaited(_quickSell(print: true));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _canQuickSell(CartState cart) =>
      cart.isNotEmpty && !_processing && !_cameraOpen;

  // ───────────────────────── البيع ─────────────────────────

  /// بيع نقدي فوري: بلا اسم زبونة، بلا أي نافذة تأكيد.
  Future<void> _quickSell({required bool print}) =>
      _completeSale(printReceipt: print, askCustomer: false);

  /// زرّ الدفع: نفس البيع النقدي مع بطاقة اسم الزبونة الاختيارية.
  Future<void> _payButton() =>
      _completeSale(printReceipt: false, askCustomer: true);

  Future<void> _completeSale({
    required bool printReceipt,
    required bool askCustomer,
  }) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || _processing) return;

    var customerName = cart.customerName;
    var isVip = cart.isVip;

    if (askCustomer) {
      final choice = await showCustomerDialog(
        context,
        initialName: customerName,
        initialVip: isVip,
        vipPercent: ref.read(vipDiscountPercentProvider),
      );
      if (choice == null) return; // ألغى المستخدم.
      customerName = choice.name;
      isVip = choice.isVip;
      ref.read(cartProvider.notifier).setCustomer(
            name: customerName,
            id: cart.customerId,
            isVip: isVip,
          );
    }

    final totals = ref.read(cartTotalsProvider);
    final repo = ref.read(salesRepositoryProvider);
    if (repo == null) return;

    setState(() => _processing = true);

    final sale = repo.newSale(
      items: ref.read(cartProvider).toSaleItems(),
      discount: totals.discount,
      vipDiscount: totals.vipDiscount,
      paymentMethod: PaymentMethod.cash,
      actor: ref.read(actorProvider),
      customerName: customerName,
      customerId: cart.customerId,
      isVip: isVip,
    );

    final lookup = {for (final l in ref.read(cartProvider).lines) l.product.id: l.product};

    // ═══ بيع متفائل ═══
    // لا ننتظر الخادم: البائع يرى النجاح فوراً والزبونة لا تنتظر.
    // Firestore يكتب محلياً ثم يُزامن — وإن انقطع الإنترنت أُكمل البيع.
    unawaited(
      repo.commitSale(sale, productLookup: lookup).catchError((Object e) {
        if (mounted) showErr(context, trf('تعذّر حفظ الفاتورة: {0}', [e]));
      }),
    );

    if (printReceipt) {
      unawaited(_printReceipt(sale));
    }

    ref.read(cartProvider.notifier).clear();
    unawaited(ref.read(cartSyncProvider)?.clearShared() ?? Future.value());

    if (mounted) {
      setState(() => _processing = false);
      showOk(
        context,
        trf('تمّ البيع — {0}{1}', [money(sale.total), printReceipt ? tr(' · جارٍ الطباعة') : '']),
      );
      _clearSearch();
    }
  }

  Future<void> _printReceipt(Sale sale) async {
    final outcome = await ref.read(printServiceProvider).printReceipt(sale);
    if (!mounted || outcome.ok) return;
    showErr(context, outcome.message);
  }

  Future<void> _sellOnCredit() async {
    final cart = ref.read(cartProvider);
    final totals = ref.read(cartTotalsProvider);
    if (cart.isEmpty) return;

    final choice = await showCreditDialog(
      context,
      total: totals.total,
      initialName: cart.customerName,
    );
    if (choice == null || !mounted) return;

    final repo = ref.read(salesRepositoryProvider);
    final posRepo = ref.read(posRepositoryProvider);
    if (repo == null || posRepo == null) return;

    setState(() => _processing = true);
    try {
      final accountId = await posRepo.findOrCreateCreditAccount(
        choice.name,
        choice.phone,
      );

      final sale = repo.newSale(
        items: cart.toSaleItems(),
        discount: totals.discount,
        vipDiscount: totals.vipDiscount,
        paymentMethod: PaymentMethod.credit,
        actor: ref.read(actorProvider),
        paidAmount: choice.paid,
        customerName: choice.name,
        isVip: cart.isVip,
      );

      await repo.commitSale(
        sale,
        productLookup: {for (final l in cart.lines) l.product.id: l.product},
        creditAccountId: accountId,
        creditPhone: choice.phone,
      );

      ref.read(cartProvider.notifier).clear();
      unawaited(ref.read(cartSyncProvider)?.clearShared() ?? Future.value());
      if (mounted) {
        showOk(context, trf('سُجّل الكريدي — الباقي {0}', [money(sale.remaining)]));
        _clearSearch();
      }
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر تسجيل الكريدي: {0}', [e]));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _createReservation() async {
    final cart = ref.read(cartProvider);
    final totals = ref.read(cartTotalsProvider);
    if (cart.isEmpty) return;

    final choice = await showReservationDialog(
      context,
      total: totals.total,
      initialName: cart.customerName,
    );
    if (choice == null || !mounted) return;

    final posRepo = ref.read(posRepositoryProvider);
    if (posRepo == null) return;

    setState(() => _processing = true);
    try {
      final actor = ref.read(actorProvider);
      await posRepo.createReservation(
        Reservation(
          id: '',
          customerName: choice.name,
          phone: choice.phone,
          items: cart.toSaleItems(),
          total: totals.total,
          deposit: choice.deposit,
          note: choice.note,
          createdBy: actor.uid,
          createdByName: actor.name,
        ),
        productLookup: {for (final l in cart.lines) l.product.id: l.product},
      );

      ref.read(cartProvider.notifier).clear();
      unawaited(ref.read(cartSyncProvider)?.clearShared() ?? Future.value());
      if (mounted) {
        showOk(context, trf('سُجّل الحجز — العربون {0}', [money(choice.deposit)]));
        _clearSearch();
      }
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر تسجيل الحجز: {0}', [e]));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _holdCart() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final choice = await showHoldDialog(context);
    if (choice == null || !mounted) return;

    try {
      await ref.read(posRepositoryProvider)?.holdCart(
            HeldCart(
              id: '',
              name: choice.name,
              note: choice.note,
              items: cart.toSaleItems(),
              discount: cart.discount,
              createdByName: ref.read(actorProvider).name,
            ),
          );
      ref.read(cartProvider.notifier).clear();
      unawaited(ref.read(cartSyncProvider)?.clearShared() ?? Future.value());
      if (mounted) {
        showOk(context, tr('عُلّقت السلة'));
        _clearSearch();
      }
    } catch (e) {
      if (mounted) showErr(context, '$e');
    }
  }

  Future<void> _loadHeldCart() async {
    final cart = await showHeldCartsSheet(context);
    if (cart == null || !mounted) return;

    final inventory = {for (final p in ref.read(inventoryProvider)) p.id: p};
    final lines = <CartLine>[];
    for (final item in cart.items) {
      final product = inventory[item.productId];
      if (product == null) continue; // منتج حُذف بعد التعليق.
      lines.add(CartLine(
        product: product,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
      ));
    }

    ref.read(cartProvider.notifier).replaceAll(
          CartState(lines: lines, discount: cart.discount),
        );
    await ref.read(posRepositoryProvider)?.removeHeldCart(cart.id);

    if (mounted) {
      final missing = cart.items.length - lines.length;
      showOk(
        context,
        missing > 0
            ? trf('حُمّلت السلة — {0} منتجاً لم يعد موجوداً', [missing])
            : tr('حُمّلت السلة'),
      );
      _clearSearch();
    }
  }

  // ───────────────────────── البناء ─────────────────────────

  @override
  Widget build(BuildContext context) {
    // تفعيل مزامنة السلة بين الأجهزة ما دامت هذه الشاشة مفتوحة.
    ref.watch(cartSyncProvider);

    final inventory = ref.watch(inventoryProvider);
    final storeSettings =
        ref.watch(storeSettingsProvider).value ?? const StoreSettings();

    // الأنواع المعروضة: ما ضُبط في الإعدادات + أي نوع مستعمل في المخزون
    // ولم يُضبط بعد (حتى لا تختفي منتجات من الفرز).
    final categories = <String>{
      ...storeSettings.categories,
      ...inventory.map((p) => p.category).where((c) => c.trim().isNotEmpty),
    }.toList()
      ..sort();

    var gridProducts = _barcodeMatches ??
        (_query.trim().isEmpty
            ? inventory
            : inventory.where((p) => p.matches(_query)).toList());
    if (_category != null && _barcodeMatches == null) {
      gridProducts =
          gridProducts.where((p) => p.category == _category).toList();
    }

    // ⚠️ العرض فقط — لا الارتفاع (انظر _wideLayoutBreakpoint).
    final isWide = MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;

    final cartPanel = CartPanel(
      busy: _processing,
      showKeyboardHint: _isDesktop,
      onPay: _payButton,
      onCredit: _sellOnCredit,
      onReservation: _createReservation,
      onHold: _holdCart,
      onShowHeld: _loadHeldCart,
    );

    final searchBar = Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: AppSearchField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        autofocus: _isDesktop,
        hint: tr('امسح الباركود أو ابحث بالاسم'),
        resultCount: gridProducts.length,
        onChanged: (v) => setState(() {
          _query = v;
          _barcodeMatches = null;
        }),
        onSubmitted: _submitSearch,
        onScan: _scanContinuous,
      ),
    );

    final categoryBar = categories.isEmpty
        ? const SizedBox.shrink()
        : SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(tr('الكل')),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(
                        () => _category = _category == c ? null : c,
                      ),
                    ),
                  ),
              ],
            ),
          );

    return Focus(
      // جدّ لا يأخذ التركيز أبداً — يستقبل ما لم يستهلكه العنصر المركَّز.
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: AppScaffold(
        route: AppRoutes.pos,
        title: tr('نقطة البيع'),
        actions: [
          IconButton(
            tooltip: tr('مسح متواصل بالكاميرا'),
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _cameraOpen ? null : _scanContinuous,
          ),
          IconButton(
            tooltip: tr('السلال المعلّقة'),
            icon: const Icon(Icons.pause_circle_outline),
            onPressed: _loadHeldCart,
          ),
        ],
        body: isWide
            ? Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        searchBar,
                        categoryBar,
                        Expanded(
                          child: ProductGrid(
                            products: gridProducts,
                            onTap: _addToCart,
                            emptyMessage: _query.isEmpty
                                ? tr('المخزون فارغ')
                                : trf('لا نتائج لـ «{0}»', [_query]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 380,
                    child: Container(
                      color: Colors.white,
                      child: cartPanel,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  searchBar,
                  categoryBar,
                  Expanded(
                    flex: 2,
                    child: ProductGrid(
                      products: gridProducts,
                      onTap: _addToCart,
                      emptyMessage: _query.isEmpty
                          ? tr('المخزون فارغ')
                          : trf('لا نتائج لـ «{0}»', [_query]),
                    ),
                  ),
                  // ارتفاع محدود للسلة حتى يبقى زرّ الدفع ظاهراً دائماً.
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                      minHeight: 260,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                    child: cartPanel,
                  ),
                ],
              ),
      ),
    );
  }
}
