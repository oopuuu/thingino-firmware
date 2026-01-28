Vanhua Z55i
===========

https://www.ezhdt.cn/product/103.html

- Module name: VN-NM-Z55I
- Manufacturer: [Vanhua](https://vanhua.en.alibaba.com/)
- Board: T31N_GC4653_FULL_V2_01
- SoC: Ingenic T31X
- Sensor: Galaxycore GC4653
- Flash: XMC 25QH128CHIQ
- Dimensions: 38 × 38 mm (1.50 × 1.50 inch)
- ODM: https://www.ezhdt.com/
- App/Cloud: http://antsvision.com/

### Ports

#### Audio port

4-pin Molex PicoBlade

#### Ethernet port + Power

8-pin Molex PicoBlade

#### IRCUT port

2-pin Molex PicoBlade, 90 deg.

##### USB port

4-pin Molex PicoBlade, 90 deg.


### GPIO
/sys/class/gpio/gpio8    out   0
/sys/class/gpio/gpio9    in    0
/sys/class/gpio/gpio10   out   0
/sys/class/gpio/gpio11   out   0
/sys/class/gpio/gpio14   in    1
/sys/class/gpio/gpio16   in    1
/sys/class/gpio/gpio17   out   0
/sys/class/gpio/gpio53   out   0
/sys/class/gpio/gpio57   out   0    IRCUT1
/sys/class/gpio/gpio58   out   0    IRCUT2

### Installation

Connect to the device UART port using a USB-to-serial adapter and a terminal
emulator. The default baud rate is 115200.

```
screen /dev/ttyUSB0 115200
```

Copy password `hdt2020t31` into buffer, boot the device and press `Ctrl-c` to
terminate boot routine. Paste the password into the terminal and press `Enter`.
You should see the bootloader prompt.

Place fresh image of Thingino firmware on your TFTP server and run the following
commands to download and flash the firmware onto the device:

```
setenv ipaddr 192.168.1.10
setenv serverip 192.168.1.123
tftpdownload thingino-vanhua_z55i.bin
```

When the process is complete, reboot the device:

```
reset
```
