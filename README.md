# K65 Computer and Software

This is the design of my own 6502-based computer and software.

"There are many like it, but this one is mine."

## Design

The initial design is based off of Ben Eater's [6502 kit](https://eater.net/6502) and series.

Changes from Ben's design:
- Additional 6522 VIA for more I/O
- 6551 ACIA for serial port access
- Uses an ATF22V10C instead of 7400-series logic for address decoding logic
- 1.8432 MHz clock (shared with ACIA) used instead of 1MHz clock (likely increased in the future as well)

## Goals

- Basic OS/monitor support for displaying/altering memory, loading programs, etc
- XMODEM support for loading programs over serial
- SD card support with FAT16
- Sound support
- Video (stretch goal)

