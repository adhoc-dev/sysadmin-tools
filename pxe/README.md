# Notas

Coloque las images a compartir en la carpeta iso

## Levantar el docker compose

```sh
docker-compose up
```

## Management

Acceda a la URL [http://127.0.0.1:26000/](http://127.0.0.1:26000/) provista desde el navegador

### En la solapa "Boot Information"

Active el servidor con el botón "Run"

![run](/img/run.png)

### En la solapa "Image management"

Van a figurar las images disponibles

![images](/img/i.png)

### En la solapa "Configuration"

![Config](/img/config.png)

Están las configuraciones:

- Boot Configuration:

  - DHCP Server Mode: "Internal"

    Recomendamos dejarlo asi. Esto significa que el servidor DHCP va a estar activo y sirviendo cuando un PXE solicite algo. Puede intervenir con el servidor de la red local, pero en general no hay problemas y es lo mas fácil de configurar.

  - Boot Background Mode: "CLI"

    La version mas simple, sin interfaz gráfica, es solo para seleccionar la imagen a instalar

  - EFI Boot File: "ipxe.efi"

    Para boot UEFI

## Install SO from LAN

![set bot 1](/img/b1.png)
![set bot 2](/img/b2.png)
![1](/img/w1.png)
![2](/img/w2.png)

## Thobleshoting

Si no podemos conectarnos a la misma red la maquina destino y donde corremos este servidor, podemos conectar maquina con maquina con un cable eth

En la computadora donde corre iventoy configurar en la red una IP estática (de otra red)

## Flash img

```sh
sudo dd if=~/repositorios/pxe_server/config/iso/debian-12.7.0-amd64-DVD-1.iso of=/dev/sda bs=4M status=progress
sync
```

https://etcher.balena.io/#download-etcher

[DEB](https://github.com/balena-io/etcher/releases/download/v1.19.21/balena-etcher_1.19.21_amd64.deb)

```sh
# Requirements
sudo apt-get install gconf2 libgdk-pixbuf2.0-0 libgdk-pixbuf-xlib-2.0-0
# Install
wget https://github.com/balena-io/etcher/releases/download/v1.19.21/balena-etcher_1.19.21_amd64.deb
sudo dpkg -i balena-etcher_1.19.21_amd64.deb
```
