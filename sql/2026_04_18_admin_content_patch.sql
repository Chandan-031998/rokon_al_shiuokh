-- Admin content management patch
-- Adds CMS pages, FAQ entries, and support/contact settings.

begin;

create table if not exists cms_pages (
  id bigserial primary key,
  slug varchar(160) not null unique,
  title varchar(180) not null,
  section varchar(60) not null,
  excerpt varchar(280),
  body text,
  image_url text,
  cta_label varchar(80),
  cta_url text,
  metadata_json jsonb not null default '{}'::jsonb,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists faqs (
  id bigserial primary key,
  question varchar(240) not null,
  answer text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists support_settings (
  id bigserial primary key,
  contact_email varchar(180),
  contact_phone varchar(40),
  contact_address text,
  support_hours varchar(180),
  whatsapp_number varchar(40),
  whatsapp_label varchar(120),
  facebook_url text,
  instagram_url text,
  twitter_url text,
  tiktok_url text,
  snapchat_url text,
  youtube_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_cms_pages_section on cms_pages(section, sort_order);
create index if not exists idx_faqs_sort_order on faqs(sort_order);

insert into cms_pages (slug, title, section, excerpt, body, sort_order, is_active)
select * from (
  values
    ('privacy-policy', 'Privacy Policy', 'policy', 'Privacy and personal data handling overview.', 'Privacy policy content can be managed here.', 1, true),
    ('return-refund-policy', 'Return / Refund Policy', 'policy', 'Return and refund conditions.', 'Return and refund policy content can be managed here.', 2, true),
    ('delivery-policy', 'Delivery Policy', 'policy', 'Delivery timing, branch coverage, and availability.', 'Delivery policy content can be managed here.', 3, true),
    ('terms-and-conditions', 'Terms & Conditions', 'policy', 'Commercial terms and platform rules.', 'Terms and conditions content can be managed here.', 4, true),
    ('about-us', 'About Us', 'about_us', 'Brand story and company background.', 'About Us content can be managed here.', 1, true),
    ('contact-us', 'Contact Us', 'contact_us', 'Ways customers can reach your team.', 'Contact Us content can be managed here.', 1, true),
    ('homepage-hero-main', 'Homepage Hero Main', 'hero_banner', 'Primary homepage hero banner.', 'Primary homepage hero banner content.', 1, true),
    ('homepage-collection-highlight', 'Collection Highlight', 'home_section_banner', 'Highlight a signature collection on the homepage.', 'Homepage section banner content.', 1, true),
    ('home-marketing-card-delivery', 'Delivery Promise', 'marketing_card', 'Promote branch delivery confidence.', 'Marketing card content.', 1, true),
    ('delivery-block-main', 'Delivery Information', 'delivery_information', 'Explain delivery coverage and pickup options.', 'Delivery information block content.', 1, true)
) as seed(slug, title, section, excerpt, body, sort_order, is_active)
where not exists (
  select 1 from cms_pages existing where existing.slug = seed.slug
);

insert into faqs (question, answer, sort_order, is_active)
select * from (
  values
    ('How long does delivery take?', 'Delivery timing depends on branch coverage and order volume. Configure the final answer in admin.', 1, true),
    ('Can I collect my order from a branch?', 'Yes. Pickup availability can be managed by branch in the admin panel.', 2, true)
) as seed(question, answer, sort_order, is_active)
where not exists (
  select 1 from faqs existing where existing.question = seed.question
);

insert into support_settings (id, contact_email, contact_phone, whatsapp_number, whatsapp_label)
select 1, 'support@rokonalshiuokh.com', '+966500000000', '+966500000000', 'Chat with Support'
where not exists (select 1 from support_settings where id = 1);

commit;
