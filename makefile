mirror: mirror.S     
	avra -fM mirror.S    
	avrdude -e -patmega88p -carduino -P/dev/ttyUSB0 -b19200 \
		-Uflash:w:mirror.S.hex:i

toggle: hello.S     
	avra -fM toggle.S    
	avrdude -e -patmega88p -carduino -P/dev/ttyUSB0 -b19200 \
		-Uflash:w:toggle.S.hex:i

read_fuses:
	avrdude -e -patmega88p -carduino -P/dev/ttyUSB0 -b19200 \
		-Ulfuse:r:-:i -Uhfuse:r:-:i -Uefuse:r:-:i

8m_int_fuse:
	avrdude -e -patmega88p -carduino -P/dev/ttyUSB0 -b19200 \
		-Ulfuse:w:0xe2:m -Uhfuse:w:0xdf:m -Uefuse:w:0xf9:m

def_fuse:
	avrdude -e -patmega88p -carduino -P/dev/ttyUSB0 -b19200 \
		-Ulfuse:w:0x62:m -Uhfuse:w:0xdf:m -Uefuse:w:0xf9:m

clean:
	rm *hex *obj