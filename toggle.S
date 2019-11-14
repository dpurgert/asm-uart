;***********************************************************************
;                              File: toggle.S
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
  reti

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
  call usart_init ;initialize the UART.
  sei ;enable interrupts ... 

  sbi DDRC, DDC5
  sbi PORTB, PORTB0; set PB0 as input_pullup
  ldi r18,1

loop:
  cpi r17, 0x31 ; "1"
  breq light 
  jmp loop ;do absolutely nothing

light:
  clr r17 ; clear r17
  cpi r18,1
  breq on             ;if r18=1, goto on
  inc r18             ;else increment from 0 to 1
  cbi PORTC, PORTC5   ;and turn off the LED
  jmp loop           ;back to loop

on:
  dec r18
  sbi PORTC, PORTC5
  jmp loop

