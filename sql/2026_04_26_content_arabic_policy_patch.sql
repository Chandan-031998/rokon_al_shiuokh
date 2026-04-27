alter table if exists cms_pages
  add column if not exists title_en varchar(180),
  add column if not exists title_ar varchar(180),
  add column if not exists excerpt_en varchar(280),
  add column if not exists excerpt_ar varchar(280),
  add column if not exists body_en text,
  add column if not exists body_ar text,
  add column if not exists region_code varchar(2);

alter table if exists faqs
  add column if not exists question_ar varchar(240),
  add column if not exists answer_ar text;

update cms_pages
set
  title_en = coalesce(nullif(title_en, ''), title),
  excerpt_en = coalesce(nullif(excerpt_en, ''), excerpt),
  body_en = coalesce(nullif(body_en, ''), body),
  title_ar = 'سياسة الخصوصية',
  excerpt_ar = 'كيفية التعامل مع بيانات العملاء والطلبات ومعلومات الحساب.',
  body_ar = 'نجمع فقط المعلومات اللازمة لتنفيذ الطلبات ودعم حسابات العملاء وتحسين جودة الخدمة. يتم حفظ بيانات التواصل وعناوين التوصيل وسجل الطلبات بشكل آمن، وتستخدم فقط لمعالجة الطلبات والدعم والتقارير التشغيلية. لا نبيع بيانات العملاء لأي طرف ثالث.',
  updated_at = now()
where slug = 'privacy-policy'
  and (nullif(title_ar, '') is null or nullif(excerpt_ar, '') is null or nullif(body_ar, '') is null);

update cms_pages
set
  title_en = coalesce(nullif(title_en, ''), title),
  excerpt_en = coalesce(nullif(excerpt_en, ''), excerpt),
  body_en = coalesce(nullif(body_en, ''), body),
  title_ar = 'سياسة الاسترجاع والاسترداد',
  excerpt_ar = 'إرشادات لمشكلات المنتجات والإرجاع والمبالغ المستردة المعتمدة.',
  body_ar = 'يجب على العملاء الإبلاغ عن المنتجات التالفة أو غير الصحيحة أو الناقصة في أقرب وقت ممكن بعد التوصيل أو الاستلام. تتم مراجعة طلبات الاسترداد والاستبدال بناء على حالة المنتج وحالة الطلب وسجلات تنفيذ الفرع. قد تتطلب المنتجات القابلة للتلف الإبلاغ في نفس اليوم لاعتماد الطلب.',
  updated_at = now()
where slug = 'return-refund-policy'
  and (nullif(title_ar, '') is null or nullif(excerpt_ar, '') is null or nullif(body_ar, '') is null);

update cms_pages
set
  title_en = coalesce(nullif(title_en, ''), title),
  excerpt_en = coalesce(nullif(excerpt_en, ''), excerpt),
  body_en = coalesce(nullif(body_en, ''), body),
  title_ar = 'سياسة التوصيل',
  excerpt_ar = 'نطاق تغطية الفروع ومواعيد التوصيل وإرشادات الاستلام.',
  body_ar = 'يعتمد توفر التوصيل على الفرع المحدد وحجم الطلبات الحالي ومنطقة التغطية. يمكن للعملاء مراجعة توفر التوصيل والاستلام الخاص بكل فرع أثناء إتمام الطلب. قد تختلف المدة المتوقعة خلال أوقات الذروة أو العطلات أو اضطرابات الطقس.',
  updated_at = now()
where slug = 'delivery-policy'
  and (nullif(title_ar, '') is null or nullif(excerpt_ar, '') is null or nullif(body_ar, '') is null);

update cms_pages
set
  title_en = coalesce(nullif(title_en, ''), title),
  excerpt_en = coalesce(nullif(excerpt_en, ''), excerpt),
  body_en = coalesce(nullif(body_en, ''), body),
  title_ar = 'الشروط والأحكام',
  excerpt_ar = 'شروط تصفح المنتجات والطلب والدفع والتنفيذ.',
  body_ar = 'باستخدام واجهة المتجر، يوافق العملاء على أسعار المنتجات الحالية وتوفر المخزون وقواعد التنفيذ وشروط الدفع المنشورة من قبل النشاط. قد يتم تحديث الطلبات أو إلغاؤها عند تغير المخزون أو جاهزية الفرع أو نطاق التوصيل بعد تقديم الطلب.',
  updated_at = now()
where slug = 'terms-and-conditions'
  and (nullif(title_ar, '') is null or nullif(excerpt_ar, '') is null or nullif(body_ar, '') is null);

update support_settings
set
  contact_address_ar = case
    when nullif(contact_address_ar, '') is null or contact_address_ar = contact_address
    then 'تغطية دعم فروع محايل عسير وأبها'
    else contact_address_ar
  end,
  support_hours_ar = case
    when nullif(support_hours_ar, '') is null or support_hours_ar = support_hours
    then 'ساعات الدعم اليومية تتم إدارتها من لوحة التحكم'
    else support_hours_ar
  end,
  whatsapp_label_ar = case
    when nullif(whatsapp_label_ar, '') is null or whatsapp_label_ar = whatsapp_label
    then 'تواصل عبر واتساب'
    else whatsapp_label_ar
  end,
  updated_at = now()
where id is not null;

update faqs
set
  question_ar = 'كم يستغرق التوصيل؟',
  answer_ar = 'يعتمد وقت التوصيل على الفرع المحدد ومنطقة التوصيل وحجم الطلبات الحالي. تعرض صفحة إتمام الطلب ومركز الدعم أحدث معلومات الخدمة المرتبطة بالفروع.',
  updated_at = now()
where question = 'How long does delivery take?'
  and (nullif(question_ar, '') is null or nullif(answer_ar, '') is null);

update faqs
set
  question_ar = 'هل يمكنني استلام طلبي من الفرع؟',
  answer_ar = 'نعم. يتم التحكم في توفر الاستلام حسب كل فرع. إذا كان الاستلام مفعلا للفرع المحدد، يمكن للعملاء اختياره أثناء إتمام الطلب.',
  updated_at = now()
where question = 'Can I collect my order from a branch?'
  and (nullif(question_ar, '') is null or nullif(answer_ar, '') is null);
