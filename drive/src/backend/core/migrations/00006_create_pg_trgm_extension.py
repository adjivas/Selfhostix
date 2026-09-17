from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0005_item_description"),
    ]

    operations = [
        migrations.RunSQL(
            "CREATE EXTENSION IF NOT EXISTS pg_trgm;",
            reverse_sql="DROP EXTENSION IF EXISTS pg_trgm;",
        ),
    ]