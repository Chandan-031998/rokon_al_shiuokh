# Rokon Al Shiuokh - Flutter + Flask + Supabase Starter

This is a **starter scaffold** for the Rokon Al Shiuokh commerce app.
It matches the brief for a luxury Arabic shopping experience with categories,
branches, cart, checkout, pickup/delivery, and order tracking.

## Tech Stack
- Flutter app (frontend)
- Flask REST API (backend)
- Supabase PostgreSQL + Storage

## Included
- Recommended project folder structure
- Flutter starter files
- Flask starter files
- PostgreSQL `.sql` schema for Supabase
- Basic seed data for branches and categories

## Notes
- Put your real Supabase/Postgres credentials only in backend `.env`
- Do not store DB credentials inside Flutter
- This scaffold is intended to save setup time; add full business logic screen by screen

## Branches seeded in SQL
- Mahayil Aseer (Main Branch)
- Abha Branch

## Categories seeded in SQL
- Coffee
- Spices
- Herbs & Attar
- Incense
- Nuts
- Dates
- Oils



python -m venv venv
source venv/bin/activate

Do this on your Mac

First leave the current venv:

deactivate

Check installed Python versions:

python3 --version
which python3

If you do not have Python 3.12, install it:

brew install python@3.12

Now go to the backend folder and remove the broken venv:

cd /Users/chandangirish/Downloads/rokon_al_shiuokh_flutter_flask_supabase/backend
rm -rf venv

Create a new venv using Python 3.12:

/opt/homebrew/bin/python3.12 -m venv venv
source venv/bin/activate
python --version

It should show:

Python 3.12.x

Then upgrade packaging tools:

pip install --upgrade pip setuptools wheel

Now install requirements again:

pip install -r requirements.txt

-------
Flutter frontend

flutter create .

flutter pub get

-----


flutter pub get
flutter clean
flutter run -d chrome