# Generated by Django 5.1.7 on 2025-04-05 03:20

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('auth_app', '0004_vendor_is_active_vendor_rating'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='foodlisting',
            name='images',
        ),
        migrations.RemoveField(
            model_name='foodlisting',
            name='quantity',
        ),
        migrations.RemoveField(
            model_name='foodlisting',
            name='unit',
        ),
        migrations.AddField(
            model_name='foodlisting',
            name='category',
            field=models.CharField(blank=True, max_length=100, null=True),
        ),
        migrations.AddField(
            model_name='foodlisting',
            name='image',
            field=models.ImageField(blank=True, null=True, upload_to='foods/'),
        ),
        migrations.AddField(
            model_name='foodlisting',
            name='is_available',
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name='vendor',
            name='cuisine_type',
            field=models.CharField(blank=True, max_length=100, null=True),
        ),
        migrations.AddField(
            model_name='vendor',
            name='latitude',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='vendor',
            name='longitude',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='vendor',
            name='pincode',
            field=models.CharField(blank=True, max_length=10, null=True),
        ),
    ]
