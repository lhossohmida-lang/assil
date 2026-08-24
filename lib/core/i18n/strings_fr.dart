/// قاموس الترجمة الفرنسية — **المفتاح هو النصّ العربي حرفياً**.
///
/// أي نصّ غير موجود هنا يظهر بالعربية (سقوط آمن)، فإضافة سطر واحد تكفي
/// لترجمة أي نصّ جديد. لا تُغيّر المفاتيح: هي نفسها النصوص في الكود.
///
/// ملاحظة كتابية: نستعمل الفاصلة العليا الطباعية (’) لا (')، فهي الصحيحة
/// في الفرنسية وتُغني عن الهروب داخل نصوص Dart المحصورة بعلامة مفردة.
///
/// مصطلحات مقصودة:
///  «لاروسات» → Recettes (من la recette)
///  «فارسمون» → Versement (من versement)
///  «كريدي»   → Crédit
library;

const Map<String, String> frenchStrings = <String, String>{
  // ─────────────── الأقسام والتنقّل ───────────────
  'نقطة البيع': 'Point de vente',
  'نقطة بيع ومخزون': 'Point de vente et stock',
  'المخزون': 'Stock',
  'التقارير': 'Rapports',
  'التقارير (لاروسات)': 'Rapports (recettes)',
  'رأس المال والزكاة': 'Capital et Zakât',
  'الكريديات': 'Crédits',
  'الفارسمون': 'Versements',
  'الفارسمون (الحجوزات)': 'Versements (réservations)',
  'الزبائن': 'Clients',
  'المصاريف': 'Dépenses',
  'الموردون': 'Fournisseurs',
  'المشتريات': 'Achats',
  'العمال': 'Employés',
  'الطلبات': 'Commandes',
  'الإعدادات': 'Paramètres',
  'استيراد': 'Importation',
  'استيراد منتجات': 'Importer des produits',
  'بحث في السجل': 'Recherche dans le journal',
  'تسجيل الخروج': 'Déconnexion',
  'صاحب المحل': 'Propriétaire',

  // ─────────────── أفعال عامة ───────────────
  'إلغاء': 'Annuler',
  'تأكيد': 'Confirmer',
  'حفظ': 'Enregistrer',
  'حفظ التعديل': 'Enregistrer les modifications',
  'إضافة': 'Ajouter',
  'تعديل': 'Modifier',
  'حذف': 'Supprimer',
  'إزالة': 'Retirer',
  'إغلاق': 'Fermer',
  'فتح': 'Ouvrir',
  'تطبيق': 'Appliquer',
  'تحديث': 'Actualiser',
  'متابعة': 'Continuer',
  'تراجع': 'Retour',
  'تنفيذ': 'Exécuter',
  'تسجيل': 'Enregistrer',
  'اختيار': 'Choisir',
  'إنشاء': 'Créer',
  'ضبط': 'Définir',
  'تغيير': 'Changer',
  'مسح': 'Effacer',
  'المزيد': 'Plus',
  'الكل': 'Tout',
  'لا شيء': 'Aucun',
  'بلا اسم': 'Sans nom',
  'الحالة': 'État',
  'الصف': 'Ligne',
  'جديد': 'Nouveau',
  ' جديد': ' Nouveau',
  'خطأ': 'Erreur',
  ' خطأ': ' Erreur',
  'أخطاء': 'Erreurs',
  'سيُحدَّث': 'Sera mis à jour',
  ' سيُحدَّث': ' Sera mis à jour',
  'ملاحظة': 'Remarque',
  'الوصف': 'Description',
  'الاسم': 'Nom',
  'الاسم *': 'Nom *',
  'الاسم مطلوب': 'Le nom est obligatoire',
  'الهاتف': 'Téléphone',
  'العنوان': 'Adresse',
  'اتصال': 'Appeler',
  'واتساب': 'WhatsApp',
  'دخول': 'Connexion',
  'العربية': 'Arabe',

  // ─────────────── الدخول ───────────────
  'البريد الإلكتروني': 'Adresse e-mail',
  'البريد الإلكتروني *': 'Adresse e-mail *',
  'كلمة المرور': 'Mot de passe',
  'كلمة المرور *': 'Mot de passe *',
  'كلمة المرور 6 أحرف على الأقل':
      'Le mot de passe doit faire au moins 6 caractères',
  'نسيت كلمة المرور؟': 'Mot de passe oublié ?',
  'اكتب بريداً إلكترونياً صحيحاً': 'Saisissez une adresse e-mail valide',
  'بريد إلكتروني غير صحيح': 'Adresse e-mail invalide',
  'اكتب بريدك أولاً ثم اضغط «نسيت كلمة المرور»':
      'Saisissez d’abord votre e-mail, puis appuyez sur « Mot de passe oublié »',
  'أُرسل رابط إعادة تعيين كلمة المرور إلى بريدك':
      'Un lien de réinitialisation a été envoyé à votre e-mail',

  // ─────────────── نقطة البيع ───────────────
  'امسح الباركود أو ابحث بالاسم': 'Scannez le code-barres ou cherchez par nom',
  'امسح الباركود أو اختر من المنتجات':
      'Scannez le code-barres ou choisissez un produit',
  'مسح متواصل بالكاميرا': 'Scan continu par caméra',
  'مسح بالكاميرا': 'Scanner par caméra',
  'وجّه الكاميرا إلى الباركود': 'Dirigez la caméra vers le code-barres',
  'الإضاءة': 'Éclairage',
  'السلة فارغة': 'Panier vide',
  'سلة فارغة': 'Panier vide',
  'السلال المعلّقة': 'Paniers en attente',
  'لا توجد سلال معلّقة': 'Aucun panier en attente',
  'انتظار': 'En attente',
  'تعليق': 'Mettre en attente',
  'تعليق السلة': 'Mettre le panier en attente',
  'عُلّقت السلة': 'Panier mis en attente',
  'حُمّلت السلة': 'Panier chargé',
  'اسم مميّز': 'Nom distinctif',
  'مثلاً: الزبونة ذات المعطف الأحمر': 'Ex. : la cliente au manteau rouge',
  'ابحث بالاسم أو الملاحظة أو المنتج': 'Chercher par nom, remarque ou produit',
  'كريدي': 'Crédit',
  'بيع كريدي': 'Vente à crédit',
  'تسجيل الكريدي': 'Enregistrer le crédit',
  'فارسمون': 'Versement',
  'فارسمون (حجز)': 'Versement (réservation)',
  'تسجيل الحجز': 'Enregistrer la réservation',
  'بيع': 'Vente',
  'نقداً': 'Espèces',
  'طريقة الدفع': 'Mode de paiement',
  'الزبونة (اختياري)': 'Cliente (facultatif)',
  'اسم الزبونة': 'Nom de la cliente',
  'اسم الزبونة *': 'Nom de la cliente *',
  'اسم الزبونة مطلوب في البيع بالكريدي':
      'Le nom de la cliente est obligatoire pour une vente à crédit',
  'اسم الزبونة مطلوب في الحجز':
      'Le nom de la cliente est obligatoire pour une réservation',
  'زبونة VIP': 'Cliente VIP',
  'زبونة جديدة': 'Nouvelle cliente',
  'تعديل الزبونة': 'Modifier la cliente',
  'حذف الزبونة': 'Supprimer la cliente',
  'حُفظت الزبونة': 'Cliente enregistrée',
  'حُذفت البطاقة': 'Fiche supprimée',
  'خصم VIP': 'Remise VIP',
  'نسبة خصم زبونة VIP': 'Taux de remise cliente VIP',
  'تخفيض': 'Remise',
  'تخفيض على السلة': 'Remise sur le panier',
  'مبلغ التخفيض': 'Montant de la remise',
  'بلا تخفيض': 'Sans remise',
  'التخفيض': 'La remise',
  'تعديل السعر': 'Modifier le prix',
  'السعر الجديد': 'Nouveau prix',
  'الأصلي': 'Original',
  'Enter = بيع فوري بلا طباعة  ·  Space = بيع فوري مع الطباعة':
      'Entrée = vente immédiate sans impression  ·  '
          'Espace = vente immédiate avec impression',
  'الزبون': 'Client',
  'البائع': 'Vendeur',

  // ─────────────── المنتجات والمخزون ───────────────
  'منتج جديد': 'Nouveau produit',
  'تعديل منتج': 'Modifier le produit',
  'تعديل المنتج': 'Modifier le produit',
  'حذف المنتج': 'Supprimer le produit',
  'اسم المنتج *': 'Nom du produit *',
  'المنتج': 'Produit',
  'المنتجات': 'Produits',
  'بلا منتجات': 'Aucun produit',
  'لا منتجات': 'Aucun produit',
  'المنتج غير موجود': 'Produit introuvable',
  'الباركود': 'Code-barres',
  'رقم الباركود': 'Numéro du code-barres',
  'بلا باركود': 'Sans code-barres',
  'سيُولَّد': 'Sera généré',
  'توليد رقم جديد': 'Générer un nouveau numéro',
  'هذا الباركود مستعمل في منتج آخر':
      'Ce code-barres est déjà utilisé par un autre produit',
  'الأرقام المولّدة 8 خانات: تعطي خطوطاً أعرض تُقرأ من أبعد.':
      'Les numéros générés font 8 chiffres : des barres plus larges, '
          'lisibles de plus loin.',
  'سعر الشراء *': 'Prix d’achat *',
  'سعر البيع': 'Prix de vente',
  'سعر البيع *': 'Prix de vente *',
  'سعر الشراء الجديد': 'Nouveau prix d’achat',
  'سعر البديل': 'Prix du remplaçant',
  'الكمية': 'Quantité',
  'الكمية *': 'Quantité *',
  'كمية': 'Quantité',
  'تعديل الكمية': 'Modifier la quantité',
  'حد التنبيه': 'Seuil d’alerte',
  'تحذير عند الوصول إليه': 'Alerte lorsqu’il est atteint',
  'قيمة غير صحيحة': 'Valeur invalide',
  'أدخل سعر بيع': 'Saisissez un prix de vente',
  'النوع': 'Type',
  'بلا نوع': 'Sans type',
  'الأنواع': 'Types',
  'أنواع المنتجات': 'Types de produits',
  'قميص، جبّة، سروال...': 'Chemise, qamis, pantalon...',
  'المقاسات': 'Tailles',
  'M، L، XL، 42...': 'M, L, XL, 42...',
  'الألوان': 'Couleurs',
  'اسم اللون': 'Nom de la couleur',
  'رمز اللون': 'Code couleur',
  'اختيار اللون': 'Choix de la couleur',
  'إضافة لون': 'Ajouter une couleur',
  'أبيض، كحلي، بيج...': 'Blanc, bleu marine, beige...',
  'الصور': 'Photos',
  'إضافة صور': 'Ajouter des photos',
  '(الأولى هي الغلاف)': '(la première est la couverture)',
  'المخزون فارغ': 'Stock vide',
  'المخزون فارغ — أضف أول منتج بالزر بالأسفل':
      'Stock vide — ajoutez votre premier produit avec le bouton ci-dessous',
  'قارب النفاد': 'Bientôt épuisé',
  'عرض ما قارب النفاد فقط': 'Afficher seulement ce qui est bientôt épuisé',
  'إلغاء الفلتر': 'Annuler le filtre',
  'مجموع القطع': 'Total des pièces',
  'عدد الأنواع': 'Nombre de types',
  'عدد القطع': 'Nombre de pièces',
  'القطع': 'Pièces',
  'نفد': 'Épuisé',
  'خارج المتجر': 'Hors boutique',
  'يظهر في المتجر الإلكتروني': 'Visible dans la boutique en ligne',
  'إظهاره لا يؤثّر على المخزون': 'L’afficher n’affecte pas le stock',
  'إزالة من المتجر': 'Retirer de la boutique',
  'إعادة إلى المتجر': 'Remettre dans la boutique',
  'أُزيل من المتجر الإلكتروني': 'Retiré de la boutique en ligne',
  'أُعيد إلى المتجر الإلكتروني': 'Remis dans la boutique en ligne',
  'مزامنة المتجر الإلكتروني': 'Synchroniser la boutique en ligne',
  'جارٍ مزامنة المتجر...': 'Synchronisation de la boutique...',
  'إزالة كل المنتجات من المتجر': 'Retirer tous les produits de la boutique',
  'إفراغ المتجر': 'Vider la boutique',
  'أُضيف المنتج': 'Produit ajouté',
  'حُذف المنتج': 'Produit supprimé',
  'ترحيل الصور القديمة': 'Migrer les anciennes photos',
  'لا صور تحتاج ترحيلاً': 'Aucune photo à migrer',
  'الصورة ليست بصيغة base64 صالحة': 'L’image n’est pas un base64 valide',

  // ─────────────── الاستبدال والإرجاع ───────────────
  'استبدال': 'Échanger',
  'استبدال منتج': 'Échanger un produit',
  'تأكيد الاستبدال': 'Confirmer l’échange',
  'الكمية المستبدَلة:': 'Quantité échangée :',
  'ابحث عن البديل بالاسم أو الباركود':
      'Cherchez le remplaçant par nom ou code-barres',
  'اكتب للبحث عن البديل': 'Saisissez pour chercher le remplaçant',
  'قيمة القديم': 'Valeur de l’ancien',
  'قيمة البديل': 'Valeur du remplaçant',
  'تأخذ من الزبونة': 'À encaisser de la cliente',
  'تُعيد للزبونة': 'À rendre à la cliente',
  'لا فرق': 'Aucune différence',
  'إرجاع': 'Retour',
  'يعود للمخزون ويُسجَّل مصروفاً بقيمة المبلغ المُعاد':
      'Remis en stock et enregistré comme dépense du montant remboursé',
  'يمكن تعديله': 'Modifiable',

  // ─────────────── الفواتير والسجل ───────────────
  'رقم الفاتورة': 'N° de facture',
  'صورة الفاتورة': 'Image du ticket',
  'إعادة الطباعة': 'Réimprimer',
  'حذف الفاتورة': 'Supprimer la facture',
  'حذف الفاتورة نهائياً': 'Supprimer définitivement la facture',
  'حُذفت الفاتورة': 'Facture supprimée',
  'حُذفت الفاتورة وعادت البضاعة للمخزون':
      'Facture supprimée, marchandise remise en stock',
  'الفاتورة غير موجودة': 'Facture introuvable',
  'فاتورة فارغة': 'Facture vide',
  'الفواتير': 'Factures',
  'عدد الفواتير': 'Nombre de factures',
  'التاريخ': 'Date',
  'المجموع': 'Sous-total',
  'الإجمالي': 'Total',
  'المدفوع': 'Payé',
  'المدفوع الآن': 'Payé maintenant',
  'المتبقّي': 'Restant',
  'الباقي': 'Reste',
  'الباقي (دين)': 'Reste (dette)',
  'باركود أو اسم منتج — في كل الفواتير':
      'Code-barres ou nom de produit — dans toutes les factures',
  'لا عمليات في هذه الفترة': 'Aucune opération sur cette période',
  'حذف السجلات القديمة': 'Supprimer les anciens enregistrements',
  'حذف الأقدم من:': 'Supprimer ce qui est antérieur à :',
  'شهر': 'un mois',
  '3 أشهر': '3 mois',
  '6 أشهر': '6 mois',
  'سنة': 'un an',

  // ─────────────── التقارير والصندوق ───────────────
  'اليوم': 'Aujourd’hui',
  'أمس': 'Hier',
  'الأسبوع': 'Semaine',
  'الشهر': 'Mois',
  'السنة': 'Année',
  'مخصّصة': 'Personnalisée',
  'المبيعات': 'Ventes',
  'الفائدة': 'Bénéfice',
  'الفائدة الخام': 'Bénéfice brut',
  'الفائدة بعد المصاريف': 'Bénéfice après dépenses',
  'الفائدة المنتظرة': 'Bénéfice attendu',
  'المبيعات − رأس المال المُباع': 'Ventes − coût des marchandises vendues',
  'رأس المال المُباع': 'Coût des marchandises vendues',
  'كلفة شراء ما خرج': 'Coût d’achat de ce qui est sorti',
  'لاروسات بعد المصاريف': 'Recettes après dépenses',
  'صافي النقد الداخل والخارج': 'Trésorerie nette entrée/sortie',
  'رصيد الصندوق': 'Solde de caisse',
  'رصيد الصندوق الآن': 'Solde de caisse actuel',
  'الآن — كل الفترات': 'Maintenant — toutes périodes',
  'إيداع': 'Dépôt',
  'إيداع في الصندوق': 'Dépôt en caisse',
  'سحب': 'Retrait',
  'سحب / مصروف': 'Retrait / dépense',
  'مصروف': 'Dépense',
  'السبب / ملاحظة': 'Motif / remarque',
  'المبلغ': 'Montant',
  'المبلغ المدفوع': 'Montant payé',
  'الوجهة (حساب أو عامل)': 'Destination (compte ou employé)',
  'بلا وجهة': 'Sans destination',
  'حذف الحركة': 'Supprimer l’opération',
  'حُذفت الحركة وأُعيد المبلغ': 'Opération supprimée, montant restitué',
  'سحب الأرباح': 'Retrait des bénéfices',
  'سحب أرباح — ليس مصروفاً': 'Retrait de bénéfices — pas une dépense',
  'ليس مصروفاً': 'Pas une dépense',
  'يُسحب أرباحاً': 'Retiré en bénéfices',
  'يبقى في الدرج': 'Reste dans le tiroir',
  'إغلاق الصندوق': 'Clôture de caisse',
  'كم سحبت؟': 'Combien avez-vous retiré ?',
  'كم يبقى في الصندوق للغد؟': 'Combien reste-t-il en caisse pour demain ?',
  'كل الرصيد': 'Tout le solde',
  'النصف': 'La moitié',

  // ─────────────── المصاريف ───────────────
  'حساب مصروف': 'Compte de dépense',
  'حساب مصروف جديد': 'Nouveau compte de dépense',
  'كهرباء، كراء، مشتريات...': 'Électricité, loyer, achats...',
  'أُضيف الحساب': 'Compte ajouté',
  'حذف الحساب': 'Supprimer le compte',
  'حُذف الحساب': 'Compte supprimé',
  'إعادة تسمية': 'Renommer',
  'إعادة تسمية الحساب': 'Renommer le compte',
  'لا حركات على هذا الحساب': 'Aucune opération sur ce compte',
  'مصاريف بلا حساب': 'Dépenses sans compte',
  'لا توجد حسابات مصروف ولا عمال — أضِفهم من شاشة المصاريف.':
      'Aucun compte de dépense ni employé — ajoutez-les depuis l’écran Dépenses.',

  // ─────────────── الكريديات ───────────────
  'مجموع الديون المتبقّية': 'Total des dettes restantes',
  'إخفاء الحسابات المسدَّدة': 'Masquer les comptes soldés',
  'إجمالي الدين': 'Dette totale',
  'المسدَّد': 'Réglé',
  'سجل السداد': 'Historique des règlements',
  'تسجيل دفعة': 'Enregistrer un versement',
  'دفعة': 'Versement',
  'حذف حساب الكريدي': 'Supprimer le compte crédit',
  'بلا هاتف': 'Sans téléphone',
  'ابحث بالاسم أو الهاتف': 'Chercher par nom ou téléphone',

  // ─────────────── الفارسمون ───────────────
  'العربون': 'Acompte',
  'العربون المدفوع': 'Acompte versé',
  'إجمالي الحجز': 'Total de la réservation',
  'الباقي عند الاستلام': 'Reste à la livraison',
  'البضاعة تخرج من المخزون فوراً وتعود إليه إن أُلغي الحجز.':
      'La marchandise sort du stock immédiatement et y revient si la '
          'réservation est annulée.',
  'إكمال البيع': 'Finaliser la vente',
  'إكمال الحجز': 'Finaliser la réservation',
  'إكمال': 'Finaliser',
  'إلغاء الحجز': 'Annuler la réservation',
  'أُلغي الحجز وعادت البضاعة': 'Réservation annulée, marchandise restituée',
  'جارٍ': 'En cours',
  'مكتمل': 'Terminé',
  'ملغى': 'Annulé',
  'لا حجوزات في هذا التصنيف': 'Aucune réservation dans cette catégorie',
  'ابحث بالاسم أو الهاتف أو المنتج': 'Chercher par nom, téléphone ou produit',
  'يُسجَّل مصروفاً. اتركه بلا تحديد إن احتُجز العربون.':
      'Enregistré comme dépense. Laissez décoché si l’acompte est retenu.',

  // ─────────────── الموردون والمشتريات ───────────────
  'مورّد جديد': 'Nouveau fournisseur',
  'تعديل المورّد': 'Modifier le fournisseur',
  'حذف المورّد': 'Supprimer le fournisseur',
  'حُفظ المورّد': 'Fournisseur enregistré',
  'حُذف المورّد': 'Fournisseur supprimé',
  'المورّد': 'Fournisseur',
  'المورّد *': 'Fournisseur *',
  'اختر المورّد أولاً': 'Choisissez d’abord le fournisseur',
  'مجموع ما عليك للموردين': 'Total dû aux fournisseurs',
  'مجموع المشتريات': 'Total des achats',
  'المدفوع له': 'Payé au fournisseur',
  'المتبقّي عليك': 'Restant à votre charge',
  'رصيد لك عنده': 'Avoir chez lui',
  'عليك': 'Vous devez',
  'مسدَّد': 'Soldé',
  'فواتير الشراء': 'Factures d’achat',
  'حركات الصندوق معه': 'Mouvements de caisse avec lui',
  'شراء': 'Achat',
  'شراء جديد': 'Nouvel achat',
  'حفظ فاتورة الشراء': 'Enregistrer la facture d’achat',
  'حذف فاتورة الشراء': 'Supprimer la facture d’achat',
  'قيمة المشتريات': 'Valeur des achats',
  'غير مدفوع': 'Non payé',
  'مجموع الفاتورة': 'Total de la facture',
  'تخفيض من المورّد': 'Remise du fournisseur',
  'الباقي للمورّد': 'Reste dû au fournisseur',
  'الباقي للمورّد (دَين عليك)': 'Reste dû au fournisseur (votre dette)',
  'دفع الكل': 'Tout payer',
  'بلا دفع': 'Ne rien payer',
  'ابحث عن منتج لإضافته للفاتورة': 'Cherchez un produit à ajouter à la facture',
  'ابحث بالمورّد أو المنتج أو رقم الفاتورة':
      'Chercher par fournisseur, produit ou n° de facture',
  'الفاتورة فارغة — ابحث عن منتج أو امسح باركوده':
      'Facture vide — cherchez un produit ou scannez son code-barres',
  'لا موردين بعد — أضف أول مورّد بالزر بالأسفل':
      'Aucun fournisseur — ajoutez le premier avec le bouton ci-dessous',
  'لا موردين بعد — أضف مورّداً من شاشة الموردين أولاً.':
      'Aucun fournisseur — ajoutez-en un depuis l’écran Fournisseurs.',
  'لا مشتريات مسجّلة': 'Aucun achat enregistré',
  'يخرج المبلغ من الصندوق كـ«شراء بضاعة» — لا يُحسب مصروفاً ولا يُنقص الفائدة.':
      'Le montant sort de la caisse comme « achat de marchandise » — '
          'ni dépense, ni réduction du bénéfice.',
  'أضف منتجاً واحداً على الأقل': 'Ajoutez au moins un produit',

  // ─────────────── العمال ───────────────
  'عامل جديد': 'Nouvel employé',
  'حذف العامل': 'Supprimer l’employé',
  'حُذف العامل': 'Employé supprimé',
  'أُنشئ حساب العامل': 'Compte employé créé',
  'الأقسام المسموح بها': 'Sections autorisées',
  'الراتب': 'Salaire',
  'نوع الراتب': 'Type de salaire',
  'يومي': 'Journalier',
  'شهري': 'Mensuel',
  'مبيعاته': 'Ses ventes',
  'سحوباته': 'Ses retraits',
  'مجموع السحوبات': 'Total des retraits',
  'لا مبيعات لهذا العامل بعد': 'Aucune vente pour cet employé',
  'لا سحوبات مسجّلة لهذا العامل': 'Aucun retrait enregistré pour cet employé',

  // ─────────────── الطلبات ───────────────
  'مؤكَّد': 'Confirmée',
  'مُرسَل': 'Expédiée',
  'مُسلَّم': 'Livrée',
  'تأكيد وحجز': 'Confirmer et réserver',
  'أُكِّد الطلب وحُجزت البضاعة': 'Commande confirmée, marchandise réservée',
  'شحن': 'Expédier',
  'شُحن الطلب وخرجت البضاعة من المخزون':
      'Commande expédiée, marchandise sortie du stock',
  'تمّ التسليم': 'Livrée',
  'سُجّل التسليم': 'Livraison enregistrée',
  'إلغاء الطلب': 'Annuler la commande',
  'أُلغي الطلب': 'Commande annulée',
  'حذف الطلب': 'Supprimer la commande',
  'حُذف الطلب': 'Commande supprimée',
  'الطلب غير موجود': 'Commande introuvable',
  'لا طلبات في هذا التصنيف': 'Aucune commande dans cette catégorie',
  'ابحث بالاسم أو الهاتف أو رقم الطلب':
      'Chercher par nom, téléphone ou n° de commande',
  'استفسار — ليس طلب شراء': 'Demande d’information — pas un achat',
  'سيُحرَّر المحجوز وتعود البضاعة متاحة للبيع.':
      'La réservation sera libérée et la marchandise redeviendra disponible.',
  'سيُعلَّم الطلب كملغى.': 'La commande sera marquée comme annulée.',
  'التوصيل': 'Livraison',
  'ملصق شحن': 'Étiquette d’expédition',
  'ملصق الشحن': 'Étiquette d’expédition',

  // ─────────────── رأس المال والزكاة ───────────────
  'رأس المال': 'Capital',
  'المخزون كلّه مقوَّماً بسعر الشراء.':
      'Tout le stock valorisé au prix d’achat.',
  'قيمته بسعر البيع': 'Sa valeur au prix de vente',
  'الزكاة': 'Zakât',
  'ربع العشر ٢٫٥٪': 'Le quart du dixième 2,5 %',
  'تفصيل الوعاء (بسعر البيع)': 'Détail de l’assiette (au prix de vente)',
  'نقود الصندوق': 'Argent en caisse',
  'كريديات الزبائن (المتبقّي)': 'Crédits clients (restant)',
  'دين مرجوّ فتجب فيه الزكاة': 'Créance recouvrable, donc soumise à la zakât',
  'مجموع الوعاء': 'Total de l’assiette',

  // ─────────────── الطباعة ───────────────
  'وصل البيع': 'Ticket de vente',
  'تيكت الباركود': 'Étiquette code-barres',
  'طباعة': 'Imprimer',
  'طباعة تيكت': 'Imprimer une étiquette',
  'طباعة تجريبية': 'Impression de test',
  'الطابعة': 'Imprimante',
  'نافذة الطباعة (اختيار يدوي)': 'Boîte de dialogue d’impression (manuel)',
  'بلا طابعة محدَّدة': 'Aucune imprimante sélectionnée',
  'أُرسل للطباعة': 'Envoyé à l’impression',
  'أُلغيت الطباعة': 'Impression annulée',
  'أُرسل إلى طابعة الحاسوب 🖨': 'Envoyé à l’imprimante du PC 🖨',
  'الطباعة عن بُعد': 'Impression à distance',
  'تعذّر إرسال أمر الطباعة': 'Impossible d’envoyer l’ordre d’impression',
  'لا توجد طابعة مضبوطة على حاسوب المحل — اخترها من الإعدادات':
      'Aucune imprimante configurée sur le PC — choisissez-en une dans les '
          'paramètres',
  'عرض البكرة (مم)': 'Largeur du rouleau (mm)',
  'الهامش (مم)': 'Marge (mm)',
  'تغذية بعد القصّ (مم)': 'Avance après coupe (mm)',
  'مقياس الخط': 'Échelle de police',
  'عرض الملصق (مم)': 'Largeur de l’étiquette (mm)',
  'ارتفاع الملصق (مم)': 'Hauteur de l’étiquette (mm)',
  'الخطوة بين ملصقين (مم)': 'Pas entre deux étiquettes (mm)',
  'الملصق + الفجوة. صفر = مثل الارتفاع':
      'Étiquette + espace. Zéro = comme la hauteur',
  'دقّة الطابعة (dpi)': 'Résolution (dpi)',
  'يُحسب بها عرض الباركود': 'Sert à calculer la largeur du code-barres',
  'إزاحة أفقية (مم)': 'Décalage horizontal (mm)',
  'إزاحة عمودية (مم)': 'Décalage vertical (mm)',
  'العرض (مم)': 'Largeur (mm)',
  'الارتفاع (مم)': 'Hauteur (mm)',
  'العرض': 'Largeur',
  'إطار معايرة': 'Cadre de calibrage',
  'ضبط ورق الدرايفر قبل الطباعة':
      'Régler le format papier du pilote avant impression',
  'اضبط ورق الدرايفر ثم قِس النتيجة':
      'Régler le papier du pilote puis mesurer le résultat',
  'تشخيص الطابعة': 'Diagnostic de l’imprimante',
  'تشخيص ورق الطابعة': 'Diagnostic du format papier',
  'الملصق المطلوب': 'Étiquette demandée',
  'فورم الدرايفر الفعلي': 'Format réel du pilote',
  'ملصقات لكل طباعة': 'Étiquettes par impression',
  'لا هدر': 'Aucun gaspillage',
  'تعذّر القياس': 'Mesure impossible',
  'إعادة القياس': 'Mesurer à nouveau',
  'متاح على ويندوز فقط.': 'Disponible sur Windows uniquement.',
  'وضوح الباركود': 'Netteté du code-barres',
  'ممتاز': 'Excellent',
  'على الحافة': 'Limite',
  'لا يُقرأ': 'Illisible',
  'معاينة الوصل': 'Aperçu du ticket',
  'معاينة التيكت': 'Aperçu de l’étiquette',
  'معاينة الملصق': 'Aperçu de l’étiquette',
  'تحديث المعاينة': 'Actualiser l’aperçu',
  'الصورة مولّدة من نفس الملف الذي يُرسَل للطابعة.':
      'L’image provient du fichier exact envoyé à l’imprimante.',
  'محتوى الوصل': 'Contenu du ticket',
  'طباعة اسم المحل': 'Imprimer le nom du magasin',
  'محاذاة الاسم': 'Alignement du nom',
  'الشعار': 'Logo',
  'طباعة الشعار': 'Imprimer le logo',
  'محاذاة الشعار': 'Alignement du logo',
  'الشعار المضمَّن': 'Logo intégré',
  'اختيار صورة': 'Choisir une image',
  'حُفظ شعار الوصل': 'Logo du ticket enregistré',
  'أسطر حرّة على الوصل': 'Lignes libres sur le ticket',
  'اكتب ما شئت: فيسبوك، رقم الهاتف، عبارة شكر، شروط الإرجاع...':
      'Écrivez ce que vous voulez : Facebook, téléphone, remerciement, '
          'conditions de retour...',
  'لا أسطر — اضغط «سطر» لإضافة أول سطر.':
      'Aucune ligne — appuyez sur « Ligne » pour en ajouter une.',
  'سطر': 'Ligne',
  'سطر جديد': 'Nouvelle ligne',
  'تعديل السطر': 'Modifier la ligne',
  'النصّ': 'Texte',
  'المحاذاة': 'Alignement',
  'الموضع': 'Position',
  'أعلى الوصل': 'Haut du ticket',
  'أسفل الوصل': 'Bas du ticket',
  'خط عريض': 'Gras',
  'الحجم': 'Taille',
  'يمين': 'Droite',
  'وسط': 'Centre',
  'يسار': 'Gauche',
  'رموز QR للتواصل': 'QR codes des réseaux',
  'رمز فيسبوك': 'QR Facebook',
  'رمز إنستغرام': 'QR Instagram',
  'حجم الرمز': 'Taille du QR',
  'كتابة اسم الشبكة تحت الرمز': 'Écrire le nom du réseau sous le QR',
  'معاينة رموز QR': 'Aperçu des QR codes',
  'شكراً لتسوّقكم معنا': 'Merci de votre visite',

  // ─────────────── الإعدادات ───────────────
  'الرقم السرّي': 'Code secret',
  'الرقم الجديد': 'Nouveau code',
  'تأكيد الرقم': 'Confirmer le code',
  'تغيير الرقم السرّي': 'Changer le code secret',
  'ضبط رقم سرّي': 'Définir un code secret',
  'الرقم السرّي خاطئ': 'Code secret incorrect',
  'الرقم السرّي 4 أرقام على الأقل': 'Le code doit faire au moins 4 chiffres',
  'الرقمان غير متطابقين': 'Les deux codes ne correspondent pas',
  'حُفظ الرقم السرّي': 'Code secret enregistré',
  'مضبوط — يقفل كل الأقسام عدا نقطة البيع':
      'Défini — verrouille toutes les sections sauf le point de vente',
  'غير مضبوط — كل الأقسام مفتوحة للجميع':
      'Non défini — toutes les sections sont ouvertes à tous',
  'إقفال كل الأقسام الآن': 'Verrouiller toutes les sections maintenant',
  'يُطلب الرقم السرّي من جديد لكل قسم':
      'Le code sera redemandé pour chaque section',
  'أُقفلت كل الأقسام': 'Toutes les sections sont verrouillées',
  'المتجر': 'Magasin',
  'اسم المحل': 'Nom du magasin',
  'اسم المحل على المطبوعات': 'Nom du magasin sur les impressions',
  'يُغيَّر من AppConstants.storeDisplayName في الكود':
      'Se modifie via AppConstants.storeDisplayName dans le code',
  'المظهر واللغة': 'Apparence et langue',
  'اللغة': 'Langue',
  'لون التطبيق': 'Couleur de l’application',
  'الوضع الداكن': 'Mode sombre',
  'مبنيّ بألوان صريحة — لا يتبع النظام':
      'Construit avec des couleurs explicites — ne suit pas le système',
  'شعار المحل خلف الشاشات': 'Logo du magasin en filigrane',
  'إظهار العلامة المائية': 'Afficher le filigrane',
  'الوضوح': 'Opacité',
  'تظهر في بطاقة المنتج وفي فرز نقطة البيع.':
      'Apparaissent dans la fiche produit et le filtre du point de vente.',
  'تُكتب كما تريدها أن تظهر على بطاقة المنتج.':
      'Saisissez-les telles qu’elles doivent apparaître sur la fiche produit.',
  'اللون يُختار من دائرة الألوان بدقّة، ويظهر في بطاقة المنتج.':
      'La couleur se choisit précisément sur la roue chromatique et apparaît '
          'sur la fiche produit.',
  'لا شيء بعد — أضف أول عنصر.': 'Rien encore — ajoutez le premier élément.',
  'لا ألوان بعد — اضغط «إضافة لون» لتظهر دائرة الألوان.':
      'Aucune couleur — appuyez sur « Ajouter une couleur » pour ouvrir la '
          'roue chromatique.',
  'لا ألوان مضبوطة — أضِفها من الإعدادات (بدائرة الألوان).':
      'Aucune couleur définie — ajoutez-les dans les paramètres '
          '(roue chromatique).',
  'لا أنواع مضبوطة — أضِفها من الإعدادات لتظهر كقائمة.':
      'Aucun type défini — ajoutez-les dans les paramètres pour les voir en '
          'liste.',
  'لا مقاسات مضبوطة — أضِفها من الإعدادات.':
      'Aucune taille définie — ajoutez-les dans les paramètres.',
  'فيسبوك وإنستغرام': 'Facebook et Instagram',
  'فيسبوك': 'Facebook',
  'إنستغرام': 'Instagram',
  'رابط فيسبوك': 'Lien Facebook',
  'رابط إنستغرام': 'Lien Instagram',
  'حفظ الروابط': 'Enregistrer les liens',
  'حُفظت الروابط': 'Liens enregistrés',
  'الروابط تظهر في المتجر الإلكتروني، ويمكن طباعة رمز QR لها على وصل البيع (من إعدادات الوصل).':
      'Les liens apparaissent dans la boutique en ligne et leur QR code peut '
          'être imprimé sur le ticket (via les réglages du ticket).',
  'أضف روابط فيسبوك وإنستغرام من قسم «فيسبوك وإنستغرام» أعلاه ليمكن طباعتها.':
      'Ajoutez les liens Facebook et Instagram dans la section ci-dessus pour '
          'pouvoir les imprimer.',

  // ─────────────── الاستيراد ───────────────
  'ماذا تستورد؟': 'Que souhaitez-vous importer ?',
  'اختيار ملف': 'Choisir un fichier',
  'ملف نموذجي': 'Fichier modèle',
  'حفظ الملف النموذجي': 'Enregistrer le fichier modèle',
  'حُفظ الملف النموذجي': 'Fichier modèle enregistré',
  'أعمدة إلزامية ناقصة': 'Colonnes obligatoires manquantes',
  'حمّل الملف النموذجي واستعمل رؤوسه — أو اكتب الرؤوس بالعربية أو الإنجليزية.':
      'Téléchargez le fichier modèle et utilisez ses en-têtes — ou écrivez-les '
          'en arabe ou en anglais.',
  'تنفيذ الاستيراد': 'Lancer l’importation',
  'انتهى الاستيراد': 'Importation terminée',
  '(ستُحدَّث بياناتهم)': '(leurs données seront mises à jour)',

  // ─────────────── رسائل وأخطاء ───────────────
  'المسح بالكاميرا غير متاح على هذا الجهاز — استعمل القارئ السلكي':
      'Le scan par caméra n’est pas disponible sur cet appareil — utilisez la '
          'douchette',
  'تعذّر قراءة ردّ Cloudinary': 'Impossible de lire la réponse de Cloudinary',
  'ردّ Cloudinary غير متوقّع': 'Réponse inattendue de Cloudinary',

  // ─────────────── عيّنات المعاينة ───────────────
  'قميص قطن أبيض': 'Chemise en coton blanc',
  'بنطال جينز': 'Pantalon en jean',
  'زبونة تجريبية': 'Cliente de test',
  'الجزائر': 'Alger',
  'حي النصر، عمارة 5': 'Cité Nasr, immeuble 5',
  '— لم تُختر —': '— non sélectionnée —',

  // ─────────────── مكمّلات ───────────────
  'إجمالي الفاتورة': 'Total de la facture',
  'إضافة المنتج': 'Ajouter le produit',
  'حُفظ التعديل': 'Modification enregistrée',
  'السعر': 'Prix',
  'ابحث بالاسم أو الباركود': 'Chercher par nom ou code-barres',
  'لا زبائن بعد — تُنشأ البطاقة تلقائياً عند البيع باسم زبونة':
      'Aucun client — la fiche se crée automatiquement lors d’une vente au '
          'nom d’une cliente',
  'سحب الأرباح يُسجَّل نوعاً مستقلاً — لا يُحسب مصروفاً ولا يُنقص «الفائدة بعد المصاريف».':
      'Le retrait de bénéfices est enregistré comme type distinct — il n’est '
          'pas compté comme dépense et ne réduit pas le « bénéfice après '
          'dépenses ».',
  'بعد الإغلاق تبدأ فترة «اليوم» من هذه اللحظة، فتعود كل الأرقام صفراً فوراً.':
      'Après la clôture, la période « Aujourd’hui » démarre à cet instant : '
          'tous les chiffres repartent immédiatement de zéro.',
  'هذا جهاز محمول: أوامر الطباعة تُرسَل إلى حاسوب المحل ليطبعها على طابعته بإعداداته.':
      'Appareil mobile : les ordres d’impression sont envoyés au PC du '
          'magasin, qui imprime avec ses propres réglages.',
  'الطابعة تتقدّم بمقدار الفورم المضبوط في درايفرها، لا بمقدار الصفحة المرسلة. لو كان فورمها أكبر من الملصق خرجت ملصقات فارغة مع كل تيكت.':
      'L’imprimante avance selon le format défini dans son pilote, et non '
          'selon la page envoyée. Si ce format dépasse l’étiquette, des '
          'étiquettes vides sortent à chaque impression.',
  'لهذا يولّد التطبيق أرقاماً من 8 خانات: الطول الفردي (13) يُجبر Code128 على تبديل مجموعة المحارف فيضيف نحو 22 وحدة، فيضيق عرض الوحدة إلى نقطتين ولا يُقرأ الرمز.':
      'C’est pourquoi l’application génère des numéros à 8 chiffres : une '
          'longueur impaire (13) force Code128 à changer de jeu de caractères '
          'et ajoute environ 22 modules, ce qui réduit le module à 2 points '
          'et rend le code illisible.',
  'الصور المخزّنة كنصّ base64 تُضخّم مستندات المنتجات وتُبطئ فتح المخزون. الترحيل يرفعها إلى Cloudinary ويترك رابطاً فقط.':
      'Les photos stockées en base64 gonflent les fiches produits et '
          'ralentissent l’ouverture du stock. La migration les envoie vers '
          'Cloudinary et ne conserve qu’un lien.',
  'هذا حساب تقريبي معين على التقدير؛ الحول والنِّصاب وتفاصيل الديون المشكوك فيها تُراجَع مع أهل العلم.':
      'Ce calcul est approximatif et sert d’estimation ; le hawl, le nisab et '
          'les créances douteuses sont à vérifier auprès de gens de science.',
  'رفع الصور غير مهيّأ — املأ cloudinaryCloudName و cloudinaryUploadPreset في app_constants.dart':
      'Envoi des photos non configuré — renseignez cloudinaryCloudName et '
          'cloudinaryUploadPreset dans app_constants.dart',
  'رفع الصور غير مهيّأ — املأ إعدادات Cloudinary في app_constants.dart':
      'Envoi des photos non configuré — renseignez les réglages Cloudinary '
          'dans app_constants.dart',
  'رفع الصور غير مهيّأ: املأ cloudinaryCloudName و cloudinaryUploadPreset في lib/core/constants/app_constants.dart':
      'Envoi des photos non configuré : renseignez cloudinaryCloudName et '
          'cloudinaryUploadPreset dans lib/core/constants/app_constants.dart',
  'رفع صور المنتجات غير مهيّأ: املأ cloudinaryCloudName و cloudinaryUploadPreset في app_constants.dart':
      'Envoi des photos produits non configuré : renseignez '
          'cloudinaryCloudName et cloudinaryUploadPreset dans '
          'app_constants.dart',
  'initialAppearanceProvider يجب حقنه في ProviderScope من main()':
      'initialAppearanceProvider doit être injecté dans ProviderScope depuis '
          'main()',
  'initialPrintSettingsProvider يجب حقنه في ProviderScope من main()':
      'initialPrintSettingsProvider doit être injecté dans ProviderScope '
          'depuis main()',

  // نصوص فيها سطر جديد — يجب أن يبقى \n في المفتاح كما هو في الكود
  'اكتب باركوداً أو اسم منتج،\nأو امسح بالكاميرا — يبحث في كل الفواتير.':
      'Saisissez un code-barres ou un nom de produit,\nou scannez — la '
          'recherche couvre toutes les factures.',
  'سيصير المتجر الإلكتروني فارغاً أمام الزبائن.\n**المخزون لا يُمسّ إطلاقاً** — يمكنك إعادة النشر بالمزامنة.':
      'La boutique en ligne apparaîtra vide aux clients.\n**Le stock n’est '
          'absolument pas touché** — vous pouvez republier via la '
          'synchronisation.',
  'لا حسابات مصروف بعد.\nأنشئ حسابات مثل: كهرباء، كراء، مشتريات...':
      'Aucun compte de dépense.\nCréez des comptes comme : électricité, '
          'loyer, achats...',
  'لا مشتريات بعد.\nسجّل أول فاتورة شراء بالزر بالأسفل — ستُحدَّث كميات المخزون وأسعار الشراء تلقائياً.':
      'Aucun achat.\nEnregistrez votre première facture d’achat avec le '
          'bouton ci-dessous — les quantités et les prix d’achat seront mis à '
          'jour automatiquement.',
  'عند الحفظ: تُضاف الكميات للمخزون، ويُحدَّث سعر شراء كل منتج إلى السعر الجديد، ويخرج المدفوع من الصندوق كـ«شراء بضاعة» — لا يُحسب مصروفاً ولا يُنقص الفائدة.\nأرباح الفواتير القديمة لا تتأثّر.':
      'À l’enregistrement : les quantités s’ajoutent au stock, le prix '
          'd’achat de chaque produit est mis à jour, et le montant payé sort '
          'de la caisse comme « achat de marchandise » — ni dépense, ni '
          'réduction du bénéfice.\nLes bénéfices des anciennes factures ne '
          'changent pas.',

  // ═══════════ قوالب فيها قيم متغيّرة (trf) ═══════════
  // {0}، {1}... تُستبدل بالقيم — حافظ عليها بنفس الترتيب.

  // ─── وحدات وعدّادات ───
  '{0} + {1} أخرى': '{0} + {1} autres',
  '{0} · {1} · {2} قطعة': '{0} · {1} · {2} pièces',
  '{0} · {1} · حجم {2}': '{0} · {1} · taille {2}',
  '{0} · {1} فاتورة · {2}': '{0} · {1} factures · {2}',
  '{0} · {1} قطعة · {2}': '{0} · {1} pièces · {2}',
  '{0} · {1} قطعة · {2}{3}': '{0} · {1} pièces · {2}{3}',
  '{0} · {1}\n{2} · {3} قطعة': '{0} · {1}\n{2} · {3} pièces',
  '{0} · متوفّر {1}': '{0} · en stock {1}',
  '{0} × {1} مم': '{0} × {1} mm',
  '{0} أرقام': '{0} chiffres',
  '{0} حجز جارٍ': '{0} réservation(s) en cours',
  '{0} حركة': '{0} opération(s)',
  '{0} طلب جديد بانتظار التأكيد':
      '{0} nouvelle(s) commande(s) en attente de confirmation',
  '{0} فاتورة': '{0} facture(s)',
  '{0} فاتورة · {1}': '{0} facture(s) · {1}',
  '{0} فاتورة · {1} قطعة': '{0} facture(s) · {1} pièce(s)',
  '{0} قطعة': '{0} pièce(s)',
  '{0} قطعة · {1} · {2}': '{0} pièce(s) · {1} · {2}',
  '{0} منتجات مطابقة — اختر من القائمة':
      '{0} produits correspondants — choisissez dans la liste',
  '{0} منتجاً ما زالت صوره مخزّنة داخل قاعدة البيانات':
      '{0} produit(s) ont encore leurs photos stockées dans la base',
  '{0} نقطة · {1}': '{0} point(s) · {1}',
  '{0}\nالراتب {1} ({2}) · سحب {3}':
      '{0}\nSalaire {1} ({2}) · retiré {3}',
  '{0}مم': '{0} mm',
  '{0}٪': '{0} %',
  'متوفّر {0}': 'En stock {0}',
  'محجوز {0}': 'Réservé {0}',
  'من أصل {0}': 'sur {0}',
  'من {0} إلى {1}': 'du {0} au {1}',
  'الصف {0}': 'Ligne {0}',
  'الصف {0}: {1}': 'Ligne {0} : {1}',

  // ─── نقطة البيع ───
  '«{0}» نفد من المخزون — أُضيف رغم ذلك':
      '« {0} » est épuisé — ajouté malgré tout',
  '«{0}» موجود في الفاتورة': '« {0} » est déjà dans la facture',
  'لا يوجد منتج بالباركود «{0}»': 'Aucun produit avec le code-barres « {0} »',
  'تمّ البيع — {0}{1}': 'Vente effectuée — {0}{1}',
  'سُجّل الكريدي — الباقي {0}': 'Crédit enregistré — reste {0}',
  'سُجّل الحجز — العربون {0}': 'Réservation enregistrée — acompte {0}',
  'حُمّلت السلة — {0} منتجاً لم يعد موجوداً':
      'Panier chargé — {0} produit(s) n’existent plus',
  'دفع  {0}': 'Payer  {0}',
  'مجموع السلة: {0}': 'Total du panier : {0}',
  'السعر الأصلي: {0}': 'Prix d’origine : {0}',
  'المتوفّر {0} فقط': 'Seulement {0} disponible(s)',
  'السلال المعلّقة ({0})': 'Paniers en attente ({0})',
  'مسح متواصل — قُرئ {0}': 'Scan continu — {0} lu(s)',
  'تعذّر فتح الكاميرا: {0}': 'Impossible d’ouvrir la caméra : {0}',
  'خصم {0}٪ تلقائي': 'Remise automatique de {0} %',
  'زبونات VIP فقط (خصم {0}٪)': 'Clientes VIP uniquement (remise {0} %)',
  'الباقي {0}': 'Reste {0}',

  // ─── المخزون والمنتجات ───
  'الكمية الآن {0}': 'Quantité désormais {0}',
  'الكمية الحالية: {0}': 'Quantité actuelle : {0}',
  'الفائدة على القطعة {0} ({1}٪)': 'Bénéfice par pièce {0} ({1} %)',
  'الفائدة على القطعة {0} · على الكمية {1}':
      'Bénéfice par pièce {0} · sur la quantité {1}',
  'تنبيه: لا فائدة بهذا السعر ({0})': 'Attention : aucun bénéfice à ce prix ({0})',
  'تنبيه: لا فائدة في هذا السعر ({0})':
      'Attention : aucun bénéfice à ce prix ({0})',
  'سيُحذف «{0}» نهائياً من المخزون ومن المتجر الإلكتروني.':
      '« {0} » sera supprimé définitivement du stock et de la boutique en '
          'ligne.',
  'رُفعت {0} صورة': '{0} photo(s) envoyée(s)',
  'أُزيل {0} منتجاً من المتجر': '{0} produit(s) retiré(s) de la boutique',
  'تمت المزامنة — {0} منتجاً في المتجر':
      'Synchronisation terminée — {0} produit(s) dans la boutique',
  'فشلت المزامنة: {0}': 'Échec de la synchronisation : {0}',
  'حجم النصّ {0} ك.ب': 'Taille du texte {0} Ko',
  'ابدأ ترحيل {0} صورة': 'Migrer {0} photo(s)',
  'رُحّل {0} · فشل {1}': 'Migrées {0} · échecs {1}',
  'انتهى: رُحّل {0}، فشل {1}': 'Terminé : {0} migrée(s), {1} échec(s)',
  'شراء {0} · بيع {1} · المخزون {2}':
      'Achat {0} · vente {1} · stock {2}',

  // ─── الفواتير والسجل ───
  'الزبونة: {0}{1}': 'Cliente : {0}{1}',
  'البائع: {0}': 'Vendeur : {0}',
  'السجل — {0} عملية': 'Journal — {0} opération(s)',
  'إرجاع «{0}»': 'Retour de « {0} »',
  'أُرجع {0} × {1}': '{0} × {1} retourné(s)',
  'تعذّر الإرجاع: {0}': 'Retour impossible : {0}',
  'المنتج الحالي: {0} ({1})': 'Produit actuel : {0} ({1})',
  'تمّ الاستبدال بـ {0}': 'Échangé contre {0}',
  'تعذّر الاستبدال: {0}': 'Échange impossible : {0}',
  'ستعود كل منتجاتها ({0} قطعة) إلى المخزون، وتُحذف حركتها من الصندوق ومن السجل.\n\nلا يمكن التراجع.':
      'Tous ses produits ({0} pièces) reviendront en stock, et son opération '
          'de caisse sera supprimée du journal.\n\nAction irréversible.',
  'ستُحذف كل الفواتير وحركات الصندوق الأقدم من {0} نهائياً.\n\nالمخزون ورأس المال لا يتأثّران.':
      'Toutes les factures et opérations de caisse antérieures au {0} seront '
          'supprimées définitivement.\n\nLe stock et le capital ne sont pas '
          'affectés.',
  'حُذف {0} سجلاً': '{0} enregistrement(s) supprimé(s)',
  'لم يُبَع «{0}» في أي فاتورة': '« {0} » n’a été vendu dans aucune facture',
  'لا نتائج لـ «{0}»': 'Aucun résultat pour « {0} »',
  'الوصل — {0}مم': 'Ticket — {0} mm',
  'تعذّر توليد صورة الوصل: {0}': 'Impossible de générer l’image du ticket : {0}',
  'تعذّر حفظ الفاتورة: {0}': 'Impossible d’enregistrer la facture : {0}',

  // ─── الصندوق والتقارير ───
  'أُودع {0}': '{0} déposé',
  'سُحب {0}': '{0} retiré',
  'سُحب {0} — {1}': '{0} retiré — {1}',
  'سيعود المبلغ {0} إلى الصندوق{1}{2}.':
      'Le montant {0} reviendra en caisse{1}{2}.',
  'أُغلق الصندوق — سُحب {0} أرباحاً، بقي {1} للغد':
      'Caisse clôturée — {0} retiré en bénéfices, {1} laissé pour demain',
  'تعذّر إغلاق الصندوق: {0}': 'Clôture de caisse impossible : {0}',
  'المصاريف {0}': 'Dépenses {0}',
  'سيُحذف حساب «{0}».\nالحركات المرتبطة به تبقى في السجل بلا حساب.':
      'Le compte « {0} » sera supprimé.\nSes opérations restent au journal, '
          'sans compte.',
  'تعذّر تحميل الحسابات: {0}': 'Chargement des comptes impossible : {0}',
  'تعذّر التحميل:\n{0}': 'Chargement impossible :\n{0}',
  'تعذّر قراءة الإعدادات: {0}': 'Lecture des paramètres impossible : {0}',

  // ─── الكريديات والفارسمون ───
  'لا كريديات{0}': 'Aucun crédit{0}',
  'المتبقّي: {0}': 'Restant : {0}',
  'دفعة من {0}': 'Versement de {0}',
  'سُجّلت دفعة {0}': 'Versement de {0} enregistré',
  'سيُحذف حساب «{0}» ودَينه المتبقّي {1}.\n\nالفواتير تبقى في السجل.':
      'Le compte « {0} » et sa dette restante de {1} seront supprimés.\n\n'
          'Les factures restent au journal.',
  'دين {0} · مسدَّد {1} · متبقٍّ {2}': 'Dette {0} · réglé {1} · restant {2}',
  'ستُنشأ فاتورة بإجمالي {0}، ويدخل الباقي {1} إلى الصندوق.\n\nالمخزون لا يتغيّر — البضاعة خرجت يوم الحجز.':
      'Une facture de {0} sera créée et le reste de {1} entrera en caisse.\n\n'
          'Le stock ne change pas — la marchandise est sortie le jour de la '
          'réservation.',
  'اكتمل الحجز — الفاتورة {0}': 'Réservation finalisée — facture {0}',
  'تعذّر إكمال الحجز: {0}': 'Finalisation impossible : {0}',
  'ستعود {0} قطعة إلى المخزون.': '{0} pièce(s) reviendront en stock.',
  'إرجاع العربون {0}': 'Rembourser l’acompte {0}',
  'تعذّر تسجيل الحجز: {0}': 'Enregistrement de la réservation impossible : {0}',
  'تعذّر تسجيل الكريدي: {0}': 'Enregistrement du crédit impossible : {0}',

  // ─── الموردون والمشتريات ───
  'المتبقّي عليك: {0}': 'Restant à votre charge : {0}',
  'دفعة إلى {0}': 'Versement à {0}',
  'سيُحذف «{0}» وحسابه.\nفواتير الشراء تبقى في سجل المشتريات.':
      '« {0} » et son compte seront supprimés.\nLes factures d’achat restent '
          'dans le journal des achats.',
  'سُجّلت الفاتورة — دخل {0} قطعة للمخزون':
      'Facture enregistrée — {0} pièce(s) entrée(s) en stock',
  'ارتفع سعر الشراء {0} (كان {1})':
      'Le prix d’achat a augmenté de {0} (il était de {1})',
  'انخفض سعر الشراء {0} (كان {1})':
      'Le prix d’achat a baissé de {0} (il était de {1})',
  'انخفض سعر الشراء {0} عن {1}':
      'Le prix d’achat a baissé de {0} par rapport à {1}',
  '⚠️ ارتفع سعر الشراء {0} عن {1}':
      '⚠️ Le prix d’achat a augmenté de {0} par rapport à {1}',
  'ستُخصم {0} قطعة من المخزون، ويُصحَّح حساب المورّد، وتُحذف حركة الصندوق.\n\n⚠️ سعر الشراء لا يعود إلى قيمته السابقة تلقائياً — قد تكون فواتير أحدث غيّرته. عدّله من بطاقة المنتج إن لزم.':
      '{0} pièce(s) seront retirées du stock, le compte fournisseur corrigé '
          'et l’opération de caisse supprimée.\n\n⚠️ Le prix d’achat ne '
          'revient pas automatiquement à sa valeur précédente — des factures '
          'plus récentes ont pu le modifier. Corrigez-le depuis la fiche '
          'produit si nécessaire.',

  // ─── العمال ───
  'سيُمنع «{0}» من الدخول نهائياً.\n\nفواتيره السابقة تبقى في السجل باسمه.':
      '« {0} » ne pourra plus se connecter.\n\nSes anciennes factures restent '
          'au journal à son nom.',
  'تعذّر تحميل العمال:\n{0}': 'Chargement des employés impossible :\n{0}',
  'تعذّر تحميل المبيعات:\n{0}': 'Chargement des ventes impossible :\n{0}',
  'تعذّر تحميل السحوبات:\n{0}': 'Chargement des retraits impossible :\n{0}',
  'تعذّر تحميل المخزون:\n{0}': 'Chargement du stock impossible :\n{0}',

  // ─── الزبائن ───
  'ستُحذف بطاقة «{0}». فواتيرها تبقى في السجل.':
      'La fiche « {0} » sera supprimée. Ses factures restent au journal.',

  // ─── الطلبات ───
  'سيُحذف الطلب {0} نهائياً.{1}':
      'La commande {0} sera supprimée définitivement.{1}',
  'طلب {0}': 'Commande {0}',
  'طلب رقم {0}': 'Commande n° {0}',
  'ملصق {0}': 'Étiquette {0}',

  // ─── الطباعة ───
  'تيكت {0}': 'Étiquette {0}',
  'وصل {0}': 'Ticket {0}',
  'تمت الطباعة{0}': 'Impression effectuée{0}',
  'فشلت الطباعة: {0}': 'Échec de l’impression : {0}',
  'الطابعة لم تقبل الوظيفة{0} — تحقّق من الورق والاتصال':
      'L’imprimante a refusé la tâche{0} — vérifiez le papier et la connexion',
  'لم تُوجد الطابعة «{0}» — اخترها من الإعدادات':
      'Imprimante « {0} » introuvable — sélectionnez-la dans les paramètres',
  'تعذّر إرسال أمر الطباعة: {0}':
      'Impossible d’envoyer l’ordre d’impression : {0}',
  'ضُبط ورق الدرايفر — {0}': 'Papier du pilote réglé — {0}',
  'ملاحظة: {0}': 'Remarque : {0}',
  'يُهدر نحو {0} ملصق مع كل تيكت':
      'Environ {0} étiquette(s) gaspillée(s) à chaque impression',
  'وضوح الباركود: {0} — {1} نقطة لأرفع خط ({2} وحدة على {3}مم)':
      'Netteté du code-barres : {0} — {1} point(s) pour la barre la plus fine '
          '({2} modules sur {3} mm)',
  'على ملصق {0}مم بدقّة {1}dpi. أرفع خط في الرمز يجب أن يكون **3 نقاط فأكثر** ليُقرأ من مسافة وبإضاءة ضعيفة.':
      'Sur une étiquette de {0} mm à {1} dpi. La barre la plus fine doit faire '
          '**3 points ou plus** pour être lue à distance et sous faible '
          'éclairage.',
  'تعذّرت المعاينة: {0}': 'Aperçu impossible : {0}',
  'قسم محمي — {0}': 'Section protégée — {0}',

  // ─── الاستيراد ───
  'استيراد {0} من ملف': 'Importer {0} depuis un fichier',
  'الصيغ المدعومة: xlsx و csv.{0}': 'Formats pris en charge : xlsx et csv.{0}',
  'الملف: {0}': 'Fichier : {0}',
  'الملف ينقصه: {0}': 'Il manque au fichier : {0}',
  'المنتجات الموجودة ({0})': 'Produits existants ({0})',
  'معاينة قبل الكتابة — {0} صفاً': 'Aperçu avant écriture — {0} ligne(s)',
  'تنفيذ الاستيراد ({0} سجلاً)': 'Lancer l’importation ({0} enregistrement(s))',
  'جارٍ الاستيراد... {0}٪': 'Importation en cours... {0} %',
  'سيُضاف {0} سجلاً جديداً{1}.':
      '{0} nouvel(aux) enregistrement(s) sera(ont) ajouté(s){1}.',
  'أُضيف {0}، حُدِّث {1}، تُخطِّي {2}، أخطاء {3}':
      '{0} ajouté(s), {1} mis à jour, {2} ignoré(s), {3} erreur(s)',
  'تفاصيل الأخطاء ({0})': 'Détail des erreurs ({0})',
  'تعذّرت قراءة الملف: {0}': 'Lecture du fichier impossible : {0}',
  'تعذّر فتح مستعرض الملفات: {0}':
      'Impossible d’ouvrir l’explorateur de fichiers : {0}',
  'تعذّر حفظ الملف: {0}': 'Impossible d’enregistrer le fichier : {0}',
  'نموذج_{0}.xlsx': 'modele_{0}.xlsx',

  // ─── عامة ───
  'أضف {0}': 'Ajouter {0}',
  'تعذّر الحفظ: {0}': 'Enregistrement impossible : {0}',
  'تعذّر الحذف: {0}': 'Suppression impossible : {0}',
  'تعذّر اختيار الصورة: {0}': 'Sélection de l’image impossible : {0}',
  'فشل رفع الصورة ({0}). تأكد أن الـ upload preset بوضع Unsigned.':
      'Échec de l’envoi de l’image ({0}). Vérifiez que l’upload preset est en '
          'mode Unsigned.',
  'خصم VIP الآن {0}٪': 'Remise VIP désormais {0} %',
  'صفحة غير موجودة: {0}': 'Page introuvable : {0}',

  // ─── مقاطع تُلحَق بنصوص أخرى (لاحظ المسافة/السطر في أوّلها) ───
  ' · جارٍ الطباعة': ' · impression en cours',
  ' الباركود اختياري — إن غاب يُولَّد رقم من 8 خانات.':
      ' Le code-barres est facultatif — s’il manque, un numéro à 8 chiffres '
          'est généré.',
  ' غير مسدَّدة': ' impayé(s)',
  '\n\n⚠️ الطلب مؤكَّد — ألغِه أولاً لتحرير المحجوز.':
      '\n\n⚠️ La commande est confirmée — annulez-la d’abord pour libérer la '
          'réservation.',
  'أعلى': 'Haut',
  'أسفل': 'Bas',

  // ─── الشعار وهوية المتجر (دفعة آب 2026) ───
  'اختيار شعار': 'Choisir un logo',
  'الافتراضي': 'Par défaut',
  'حُفظ الشعار': 'Logo enregistré',
  'أُعيد الشعار الافتراضي': 'Logo par défaut rétabli',
  'تعذّر حفظ الشعار: {0}':
      'Échec de l’enregistrement du logo : {0}',
  'الشعار مشترك بين كل الأجهزة — غيّره هنا فيتغيّر على هاتف العامل أيضاً، وفي الوصل والقائمة وشاشة الدخول.':
      'Le logo est partagé entre tous les appareils — modifiez-le ici et il change aussi sur le téléphone de l’employé, sur le ticket, dans le menu et sur l’écran de connexion.',

  // ─── الوصل ───
  'اسم المحل على الوصل': 'Nom du magasin sur le ticket',
  'اتركه فارغاً لاستعمال الاسم الافتراضي. هذا الاسم لهذا الجهاز وحده.':
      'Laissez vide pour utiliser le nom par défaut. Ce nom ne concerne que cet appareil.',

  // ─── المتجر الإلكتروني ───
  'المتجر الإلكتروني والتواصل': 'Boutique en ligne et réseaux',
  'اسم المحل في المتجر': 'Nom du magasin dans la boutique',
  'جملة تعريفية': 'Phrase de présentation',
  'هاتف للزبائن': 'Téléphone client',
  'عنوان المتجر الإلكتروني': 'Adresse de la boutique en ligne',
  'يفتحه زرّ «المتجر» في شاشة الطلبات.':
      'Ouvert par le bouton « Boutique » dans l’écran des commandes.',
  'حفظ ونشر': 'Enregistrer et publier',
  'حُفظت بيانات المتجر ونُشرت للموقع':
      'Informations enregistrées et publiées sur le site',
  'هذه البيانات تظهر في المتجر الإلكتروني للزبائن، ويمكن طباعة رمز QR للروابط على وصل البيع (من إعدادات الوصل).':
      'Ces informations apparaissent dans la boutique en ligne ; un QR code des liens peut être imprimé sur le ticket (voir les réglages du ticket).',
  'قمصان رجالية بلمسة أصيلة':
      'Chemises pour hommes, touche authentique',
  'فتح المتجر الإلكتروني': 'Ouvrir la boutique en ligne',
  'اضبط عنوان المتجر في الإعدادات أوّلاً':
      'Renseignez d’abord l’adresse de la boutique dans les réglages',
  'تعذّر فتح العنوان: {0}': 'Impossible d’ouvrir l’adresse : {0}',

  // ─── الاستيراد ───
  'استيراد موردين': 'Importer des fournisseurs',
  'استيراد كريديات': 'Importer des crédits',
  'استيراد موردين من ملف':
      'Importer des fournisseurs depuis un fichier',
  'استيراد كريديات من ملف':
      'Importer des crédits depuis un fichier',

  // ─── اسم المستخدم في السجل ───
  'اسمي في السجل': 'Mon nom dans le journal',
  'حُفظ الاسم': 'Nom enregistré',
  'تعذّر حفظ الاسم: {0}': 'Échec de l’enregistrement du nom : {0}',
  'يظهر بالبنفسجي أمام كل فاتورة بعتها، وأمام حركات الصندوق.':
      'Apparaît en violet devant chaque facture que vous avez vendue et devant les mouvements de caisse.',
  'اسم المحل الافتراضي': 'Nom par défaut du magasin',
  'يُغيَّر على الوصل من «محتوى الوصل»، وفي الموقع من «المتجر الإلكتروني».':
      'Se modifie sur le ticket via « Contenu du ticket », et sur le site via « Boutique en ligne ».',
};
