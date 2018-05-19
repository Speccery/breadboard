# breadboard platform
FPGA Breadboard project for TMS9900 CPU. This is a very simple system, containing of my own TMS9900 CPU core, 32K ROM, 32K RAM and pnr's implementation of the TMS9902 UART. The design is based on Stuart Conner's breadboard project. The ROM code contains a simple machine code debugger and Stuart's port of the Cortex Basic.

The CPU runs at 100MHz. Currently only on-chip memory is used, i.e. the ROM and RAM are provided by the FPGA. The serial port is configured for 9600-7E2. Note that this is different from what people usually use, so here we have even parity, only 7 databits and 2 stop bits.

This code runs currently on three different platforms, see pictures below. The common theme here is that all of the below can be bought from eBay at very reasonable prices. 

 ** Note: all of these require external programmers, so if you're planning to acquire one of these be sure to also get a programmer. ** 

## Xilinx XC6SLX9 Mini board
A very bare bones board. 
* Xilinx XC6SLX9 chip
* 50 MHz oscillator
* Winbond 25Q64 configuration flash ROM chip, 64 megabits (8 megabytes)

![XC6SLX9 picture](https://user-images.githubusercontent.com/18168418/40271371-22704894-5ba5-11e8-9301-0d9d349e5e0e.jpg)

## Xilinx XC6SLX16 board with an option daughter board
As of writing 2018-05-19 this board can be bought with the daughther board for around 40 euros. A very good deal.
* Xilinx XC6SXL16 chip
* 50 MHz oscillator
* Micron 25P80 congiguration flash ROM chip, 8 megabits (1 megabyte)
* 32Mbyte SDRAM chip
Daughter board (the red board) provides nice additional features:
* USB to serial port conversion, CP2102 chip. This can also provide power by briging J1.
* USB fifo CY7C68013 chip
* VGA DAC chip, 24-bit RGB output, ADV7123
![XC6SLX16 picture](https://user-images.githubusercontent.com/18168418/40271384-49ce3c5c-5ba5-11e8-925c-55ba36bf69d6.jpg)

## Altera EP4CE22 "core" board with power supply/breakout board.
* EP4CE22 FPGA chip
* 50 MHz oscillator
* ST Electronics 25P16 configuration flash ROM, presumably 16 megabits. This is not what the schematic indicates...
* 32Mbyte Hynix SDRAM chip
The power board on the bottom has breakout connectors, power supply, LEDs, programming connectors.
Since the this board does not provide an USB serial port, I used an externally wired USB to RS232 adapter. Note that 3.3V (or lower) voltage levels are required.
![EP4CE22 board](https://user-images.githubusercontent.com/18168418/40271389-598204a8-5ba5-11e8-9f86-a6f73fcdb5a6.jpg)
