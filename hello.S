;***********************************************************************
;                              File: hello.S
;                     Copyright (c): 2019, Dan Purgert
;                                  : dan@djph.net
;                   
;                           License: GNU GPL v2 only
;                       Description: This example toggles a LED on PC5   
;                                  : based on whether a '1' is sent to
;                                  : the USART.
;                       
;                     Prerequisites: 
;                                  : avra >= ??? (w/ m88PA support)
;                                  : avrdude >= 6.3-2 (Debian)
;                                  : make
;                                  : mp88def.inc (from Microchip -- 
;                                  : can be obtained in the MPLABX tool)
;***********************************************************************

.include "m88PAdef.inc"

;.equ tbuf=16
.dseg
.org 0x0120
buf: .byte 16; 16 Bytes for "Hello World!"
tx_o: .byte 2; 2 bytes for a pointer

;reset and interrupt vectors
.cseg
.org 0
rjmp setup ; Reset vector, jump to 'setup'
reti ;INT0
reti ;INT1
reti ;PCINT0
reti ;PCINT1
reti ;PCINT2
reti ;WDT   
reti ;TIM2_CMPA
reti ;TIM2_CMPB
reti ;TIM2_OVF
reti ;TIM1_CAPT
reti ;TIM1_CMPA
reti ;TIM1_CMPB
reti ;TIM1_OVF
reti ;TIM0_CMPA
reti ;TIM0_CMPB
reti ;TIM0_OVF
reti ;SPI,STC 
rjmp  USART_RXC ;USART, RX Complete
rjmp  USART_DRE;USART, UDRE Data Register Empty
reti ;USART, TX Complete
reti ;ADC       
reti ;EE_RDY
reti ;ANA_COMP
reti ;TWI
reti ;SPM_RDY
;way finished with the interrupt vectors.  Most are unused, but ... 

USART_RXC:
  lds r17, UDR0
  reti
  
USART_DRE:
  in r18, SREG ; save the status register into R18
  clr r17      ; make absolutely sure R17 is empty
  push XL
  push XH ; save X?

  lds XL, tx_o   ; load XL and XH with the memory location stored in 
  lds XH, tx_o+1 ; tx_o1:0
  ld r20, X+      ; load the byte stored at that RAM location into r20
  sts UDR0, r20  ; and transmit



  ;cp r20, r1
  cpi r20, 0x0A
  breq reset_pointer      ; and jump to reset

finish:
  sts  tx_o, XL  ; dump back out to tx_o pointer
  sts  tx_o+1, XH ; maybe? 
  out SREG, r18
  pop XH
  pop XL
  reti

reset_pointer:
  lds r17, UCSR0B ;  shut down
  cbr r17, (1<<UDRIE0)
  sts UCSR0B, r17 ; clear USART Data Register Empty interrupt

  ldi XL, low(buf)   ; I have no idea why lds [low|high](buf)
  ldi XH, high(buf)  ; doesn't reset to here, but it doesn't
  jmp finish ;jump back to setting the tx_o pointer

usart_init:
  ;baudrate = 9600
  ldi r16, 0x0C ; R16= UBRR0L, see table 20-4
  ldi r17, 0x00 ; R17= UBRR0H
  sts UBRR0H, r17
  sts UBRR0L, r16
  ;enable transmitter & receiver
  ldi r16, (1<<RXCIE0)|(1<<RXEN0) | (1<<TXEN0)
  sts UCSR0B, r16
  ;set 8N1
  ldi r16, (1<<UCSZ01)|(1<<UCSZ00)
  ret  

setup:
  ;main program start
  ldi r16, low(RAMEND)
  out SPL, r16 ;stackpointer
  ldi r16, high(RAMEND)
  out SPL, r16 ;stackpointer
  call usart_init ;initialize the UART.
  sei ;enable interrupts ... 

  sbi DDRC, DDC5
  sbi PORTB, PORTB0; set PB0 as input_pullup

  ldi XL, low(buf)
  ldi XH, high(buf)
  sts tx_o, XL
  sts tx_o+1, XH ; create txo pointer

  rcall ins_buf

  
loop:
  cpi r17, 0x31
  breq hello_tx ; if r17=1, enable transmitter / hello_world
  rjmp loop ;do absolutely nothing

hello_tx:
  ; enable USART Data Register Empty interrupts
  lds r18, UCSR0B 
  sbr r18, (1<<UDRIE0)
  sts UCSR0B, r18
  clr r17 ; make sure r17 is clear
  rjmp loop ; and go back to loop

ins_buf:
  ldi r20, 0x48; H
  st X+, r20
  ldi r20, 0x65; e
  st X+, r20
  ldi r20, 0x6c; l
  st X+, r20
  ldi r20, 0x6c; l
  st X+, r20
  ldi r20, 0x6f; o
  st X+, r20
  ldi r20, 0x20; (space)
  st X+, r20
  ldi r20, 0x57; W
  st X+, r20
  ldi r20, 0x6f; o
  st X+, r20
  ldi r20, 0x72; r
  st X+, r20
  ldi r20, 0x6c; l
  st X+, r20
  ldi r20, 0x64; d
  st X+, r20
  ldi r20, 0x21; !  
  st X+, r20
  ldi r20, 0x0A; EOT
  st X+, r20
  mov r1, r20
  ret
