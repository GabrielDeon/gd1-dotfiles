#!/usr/bin/env bash

echo "Removendo driver xpadneo..."
sudo modprobe -r hid_xpadneo

echo "Carregando driver xpad..."
sudo modprobe xpad

echo "Bloqueando xpadneo para não carregar no boot..."
echo "blacklist hid_xpadneo" | sudo tee /etc/modprobe.d/blacklist-xpadneo.conf > /dev/null

echo "Configuração concluída!"
echo "Seu controle Xbox deve funcionar normalmente agora."
