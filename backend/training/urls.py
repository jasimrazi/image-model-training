from django.urls import path

from .views import trigger_training


urlpatterns = [
    path("trigger-training/", trigger_training, name="trigger-training"),
]
