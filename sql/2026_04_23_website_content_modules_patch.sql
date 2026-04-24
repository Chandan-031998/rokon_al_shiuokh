alter table categories
  add column if not exists icon_key varchar(80);

alter table faqs
  add column if not exists question_ar varchar(240),
  add column if not exists answer_ar text;
