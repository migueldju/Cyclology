"""Hora de referencia de la ingesta: la de España. PCS da las horas de salida en hora de España (CET/CEST) para
todas las carreras, también las de fuera de Europa, así que no hace falta la zona horaria de cada país."""
from zoneinfo import ZoneInfo

MADRID = ZoneInfo("Europe/Madrid")
