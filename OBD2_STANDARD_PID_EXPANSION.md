# OTOSİNYAL OBD2 – Standard PID Expansion

Bu sürümde standart SAE/OBD-II Mode 01 yetenek keşfi genişletildi.

Eklenen gerçek ECU ölçümleri (araç destekliyorsa):
- PID 04 hesaplanan motor yükü
- PID 10 MAF hava akışı
- PID 1F motor çalışma süresi
- PID 21 MIL açıkken kat edilen mesafe
- PID 3C katalizör sıcaklığı
- PID 5C motor yağı sıcaklığı
- PID 61 sürücü tork talebi
- PID 62 gerçek motor tork yüzdesi
- PID 63 motor referans torku

Mevcut PID bitmap taraması 00/20/40/60/80/A0 bloklarını okuyarak aracın desteklediği sensörleri keşfeder. Desteklenmeyen sensörler için veri uydurulmaz.

DPF/EGR/turbo tarafında standart PID desteği varsa yetenek olarak gösterilir; üreticiye özel UDS/DID gerektiren ölçümler standart PID verisiymiş gibi gösterilmez.
