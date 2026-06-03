from django.urls import path

from .views import infer_image, trigger_training


urlpatterns = [
    path("infer/", infer_image, name="infer-image"),
    path("trigger-training/", trigger_training, name="trigger-training"),
]
