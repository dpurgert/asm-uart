;***********************************************************************
;                              File: fifo.S
;                     Copyright (c): 2019, Dan Purgert
;                                  : dan@djph.net
;                   
;                           License: GNU GPL v2 only
;                       Description: This example saves incoming bytes   
;                                  : to a buffer, then sends them back
;                                  : out in FIFO order
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
.org 0x0100 
r_buf: .byte 16; 16 Bytes for incoming data
t_buf: .byte 16; 16 Bytes for outgoing data
tx_i: .byte 2; 2 bytes for the transmit pointer (data into tx fifo)
tx_o: .byte 2; 2 bytes for the transmit pointer (data out of fifo)
rx_i: .byte 2; 2 bytes for the receive pointer  (data into rx fifo)
rx_o: .byte 2; 2 bytes for the receive pointer  (data out of fifo)

;other statics:
; XREG -> the pointer in the interrupts
; r25 -> tx counter
; r24 -> rx counter
; r23 -> SREG
; r22 -> UDR0 DATA

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
  in r23, SREG ;save SREG
  cpi r24, 0x10 ; RX_count < 16
  brlo rx_store ; space available, store the byte
  lds r22, UDR0 ; read the byte to clear the interrupt
  clr r22       ; and throw it away
  out SREG, r23
  reti

rx_store:
  push XL
  push XH ;save the XREG, just in case.
  push r20
  push r21

  lds r22, UDR0
  lds XL, rx_i
  lds XH, rx_i+1 ; XREG pointing to SRAM
  st X+, r22    ; save r22 to SRAM and increment xreg

  ldi r20, low(r_buf+16) ;figure out where the top of our 
  ldi r21, high(r_buf+16) ;SRAM segment is
  cp XL, r20
  cpc XH, r21   ; test if r20:21 = X
  breq rx_roll  ; if yes, rollover

rx_f_store: ;finish storage
  sts rx_i, XL
  sts rx_i+1, XH
  inc r24

  pop r21
  pop r20
  pop XH
  pop XL
  out SREG, r23
  reti

rx_roll:
  ldi XL, low(r_buf)  ; reset rx buffer to byte0
  ldi XH, high(r_buf) ; of the SRAM segment
  rjmp rx_f_store     ; and jump back to finish out the ISR
  
  
USART_DRE:
  in r23, SREG ; save the status register into R18

  cpi r25, 1          ;
  brsh tx_out         ; if r25 >= 1, then transmit the byte
  lds r17, UCSR0B     ; else shut down
  cbr r17, (1<<UDRIE0);
  sts UCSR0B, r17     ; clear USART Data Register Empty interrupt
  out SREG, r23       ; restore SREG
  reti                ; return from interrupt

tx_out:
  push XL
  push XH ; save X
  push r20
  push r21
  lds XL, tx_o   ; load XL and XH with the memory location stored in 
  lds XH, tx_o+1 ; tx_o1:0
  ld r22, X+     ; load the byte stored at that RAM location into r20
  sts UDR0, r22  ; and transmit

  ldi r20, low(t_buf+16) ;figure out where the top of our 
  ldi r21, high(t_buf+16) ;SRAM segment is
  cp XL, r20
  cpc XH, r21   ; test if r20:21 = X
  breq tx_roll  ; if yes, rollover

tx_f_out:
  sts  tx_o, XL   ; dump back out to tx_o pointer
  sts  tx_o+1, XH ;  
  dec r25
  out SREG, r23
  pop r21
  pop r20
  pop XH
  pop XL
  reti

tx_roll:
  ldi XL, low(t_buf)  ;reset XBUF to start of the TX 
  ldi XH, high(t_buf) ;buffer space
  rjmp tx_f_out       ;and finish up

usart_init:
  ;baudrate = 4800 @ 1 MHz internal clock
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
  out SPH, r16 ;stackpointer
  call usart_init ;initialize the UART.

  ;setup tx_buffer
  ldi XL, low(t_buf)
  ldi XH, high(t_buf)
  sts tx_i, XL
  sts tx_i+1, XH ; create txi pointer
  sts tx_o, XL
  sts tx_o+1, XH ; create txo pointer

  ;setup rx_buffer
  ldi XL, low(r_buf)
  ldi XH, high(r_buf)
  sts rx_i, XL
  sts rx_i+1, XH ; create rxi pointer
  sts rx_o, XL
  sts rx_o+1, XH ; create rxo pointer

  ldi r24, 0x0
  ldi r25, 0x0 ;set transmit and receive counters
  sei ;enable interrupts ... 

  
loop:
  tst r24       ;data in rx_count
  breq loop     ;no data in rx FIFO, back to loop
  rcall FIFO_r  ;rx count >0, read the byte
  rcall FIFO_t  ;then write it to tx buffer 
  rjmp loop     ;back to loop


FIFO_r:           ;read rx_fifo
  cpi r24, 1  
  brsh FIFO_read  
  ret             ;no bytes in rx counter, return to loop
  
FIFO_read:
  lds XL, rx_o
  lds XH, rx_o+1 ; XREG pointing to SRAM (data out of rx fifo)
  ld r19, X+
  
  ldi r20, low(r_buf+16) ;figure out where the top of our 
  ldi r21, high(r_buf+16) ;SRAM segment is
  cp XL, r20
  cpc XH, r21   ; test if r20:21 = X
  breq FIFO_r_roll

FIFO_r_save:
  sts rx_o, XL
  sts rx_o+1, XH
  dec r24
  ret

FIFO_r_roll:
  ldi XL, low(r_buf)  ; reset rx buffer to byte0
  ldi XH, high(r_buf) ; of the SRAM segment
  rjmp FIFO_r_save     ; and jump back to finish out the ISR

FIFO_t:
  cpi r25, 0x10 ; RX_count < 16
  brlo FIFO_t_wr; space available, store the byte
  ret

FIFO_t_wr:
  lds XL,tx_i
  lds XH,tx_i+1
  st X+, r19
  
  ldi r20, low(t_buf+16) ;figure out where the top of our 
  ldi r21, high(t_buf+16) ;SRAM segment is
  cp XL, r20
  cpc XH, r21   ; test if r20:21 = X
  breq FIFO_t_roll

FIFO_t_save:
  sts tx_i, XL
  sts tx_i+1, XH
  inc r25 
  lds r17, UCSR0B     ; 
  sbr r17, (1<<UDRIE0);
  sts UCSR0B, r17     ; enable USART Data Register Empty interrupt
  ret

FIFO_t_roll:
  ldi XL, low(t_buf)  ; reset rx buffer to byte0
  ldi XH, high(t_buf) ; of the SRAM segment
  rjmp FIFO_t_save     ; and jump back to finish out the ISR
