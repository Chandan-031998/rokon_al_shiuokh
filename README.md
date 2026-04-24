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

## Render Deployment

The backend already uses a Flask app factory in [`backend/app.py`](/Users/chandangirish/Downloads/rokon_al_shiuokh_flutter_flask_supabase/backend/app.py), so the correct Render start command is:

```bash
gunicorn app:create_app
```

Do not use:

```bash
gunicorn "app:create_app()"
```

The parentheses and shell quotes are wrong for Gunicorn and will cause startup failure.

If you prefer to serve the module-level app object instead, this repo also exposes `app = create_app()` and this command will work too:

```bash
gunicorn app:app
```

### Render Service Settings

Set the Root Directory to:

```bash
backend
```

Set the Start Command to one of:

```bash
gunicorn app:create_app
```

or:

```bash
gunicorn app:app
```

### Required Environment Variables

Render does not read your local `backend/.env` file automatically. Add the required values in Render under Environment.

This codebase currently reads:

```bash
DATABASE_URL
SECRET_KEY
JWT_SECRET_KEY
```

Optional startup bootstrap values:

```bash
ADMIN_BOOTSTRAP_1_EMAIL
ADMIN_BOOTSTRAP_1_PASSWORD
ADMIN_BOOTSTRAP_1_NAME
ADMIN_BOOTSTRAP_1_BRANCH
ADMIN_BOOTSTRAP_2_EMAIL
ADMIN_BOOTSTRAP_2_PASSWORD
ADMIN_BOOTSTRAP_2_NAME
ADMIN_BOOTSTRAP_2_BRANCH
ADMIN_BOOTSTRAP_EMAIL
ADMIN_BOOTSTRAP_PASSWORD
ADMIN_BOOTSTRAP_NAME
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_KEY
SUPABASE_STORAGE_BUCKET
```

Important: this repo does not currently read `DB_HOST`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME` individually. It expects a single `DATABASE_URL`.

### Startup Diagnostics

The app now logs:

- `Flask app starting...` when the factory runs
- `Startup Error: ...` if bootstrap or seed logic fails during startup

That keeps Gunicorn workers from crashing just because admin bootstrap or catalog seed logic cannot reach the database during boot.

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





echo ".env" >> .gitignore
git add .
git commit -m "Added gitignore"
git push



flutter build web --release --base-href /






deactivate

# create new env
python3.11 -m venv venv_new

# activate
source venv_new/bin/activate

# install dependencies
pip install -r requirements.txt
pip install Pillow

# run app
python app.py