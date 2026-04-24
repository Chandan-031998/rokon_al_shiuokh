alter table if exists support_settings
  add column if not exists contact_address_ar text,
  add column if not exists support_hours_ar varchar(180),
  add column if not exists whatsapp_label_ar varchar(120);

update support_settings
set
  contact_address_ar = coalesce(contact_address_ar, contact_address),
  support_hours_ar = coalesce(support_hours_ar, support_hours),
  whatsapp_label_ar = coalesce(whatsapp_label_ar, whatsapp_label)
where id is not null;
