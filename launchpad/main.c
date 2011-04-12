/******************************************************************************
* Geiger counter software (Launchpad part)
* https://github.com/hermann-kurz/geiger-counter-usb
* 
* a project from
* Martin Kurz:   martinkurz@kurzschluss.com
* Steffen Raach: sraach@gmail.com
* Hermann Kurz:  hkurz@jruby.de
* 
* using
* 
* MSP-EXP430G2-LaunchPad Software UART Transmission
*
* Original Code: From MSP-EXP430G2-LaunchPad User Experience Application
* Original Author: Texas Instruments
*
* Modified by Nicholas J. Conn - http://msp430launchpad.blogspot.com
* Date Modified: 07-25-10
* 
* Heavily extended by Hermann Kurz (hkurz@acm.org) 2011-04-01
* 
* Geiger tube output is connected to P1.3,
* if there is an impulse or you press a switch on the Launchpad 
* a counter is incremented.
* The content of the counter and the current rate of the last minute
* is continuously transmitted via pseudo com port
* with 9600, No parity, 1 Stop bit to the host. No handshake is used.
* 
* GeigerGui is used to display the rate and current counter.
* 
* Debugging:
* You can also see the output by using Hyperterm on the appropriate com port.
* 
******************************************************************************/
#define UINT_MAX 65535
#include "msp430g2231.h"
#define TXD BIT1 // TXD on P1.1
#define Bitime 104 //9600 Baud, SMCLK=1MHz (1MHz/9600)=104

 
unsigned char BitCnt; // Bit count, used when transmitting byte
unsigned int uartUpdateTimer = 10; // Loops until byte is sent
unsigned int TXByte; // Value sent over UART when Transmit() is called

// we use 16 bits to count ticks and for some helper variables
unsigned int counter = UINT_MAX - 20;
unsigned int oldCounter = UINT_MAX - 20;
unsigned int currentRate = 0;
unsigned int counterStatus;
unsigned int counterTmp;
unsigned int wdtCount=0;

// Function Definitions
void Transmit(void);
void TransmitNumber(unsigned int);
void TransmitByte(unsigned int TByte);
 
void main(void)
{
  WDTCTL = WDTPW + WDTHOLD; // Stop WDT
  IFG1 &=~WDTIFG;
  IE1 &=~WDTIE;
  WDTCTL = WDTPW + WDTHOLD;
  WDTCTL = WDT_MDLY_32; // We jump to the WDT interrupt every 32 ms
  IE1 |= WDTIE;
  
  P1DIR |= BIT0; // Set P1.0 to output and P1.3 to input direction  
  P1DIR |= BIT6; // Set P1.6 to output and P1.3 to input direction  
  
  P1OUT &= ~BIT0; // set P1.0 to Off  
  P1OUT &= ~BIT6; // set P1.0 to Off  
  P1IE |= BIT3; // P1.3 interrupt enabled  
  P1IFG &= ~BIT3; // P1.3 interrupt flag cleared  
      
  __bis_SR_register(GIE); // Enable all interrupts  
   
  BCSCTL1 = CALBC1_1MHZ; // Set range
  DCOCTL = CALDCO_1MHZ; // SMCLK = DCO = 1MHz
 
  P1SEL |= TXD; //
  P1DIR |= TXD; //
   
  __bis_SR_register(GIE); // interrupts enabled\
   
  /* Main Application Loop */
  while(1)
  {
    if ((--uartUpdateTimer == 0))
// Transmit the current counter status, a blank, the current rate (last minute) and CRLF
// over com port.
    {
      TransmitNumber(counter);
      TransmitByte(0x20);
      TransmitNumber(currentRate);
      TransmitByte(10);
      TransmitByte(13);
//wait 1 second
      __delay_cycles(1000000);
    }
  }
}

//transmits byte over com port
void TransmitByte(unsigned int TByte){
	 TXByte=TByte;
     Transmit();
     uartUpdateTimer = 10;
 }


//Transmit an unsigned int over com port
void TransmitNumber(unsigned int number){
    {
      int leadingZero = 1; // true at start
      unsigned char val;
      counterTmp = 10000;
      while(counterTmp > 0){
      	val = number / counterTmp;
            if ((val != 0 ) || (leadingZero == 0) || (counterTmp == 1)){
              leadingZero = 0;
      		  TransmitByte(0x30 + val); //Transmit character for this digit
      		  number = number - (val * counterTmp);
            }
      	counterTmp = counterTmp/10;
      }
  }
}
 

// Function Transmits Character from TXByte
void Transmit()
{
  CCTL0 = OUT; // TXD Idle as Mark
  TACTL = TASSEL_2 + MC_2; // SMCLK, continuous mode
 
  BitCnt = 0xA; // Load Bit counter, 8 bits + ST/SP
  CCR0 = TAR;
   
  CCR0 += Bitime; // Set time till first bit
  TXByte |= 0x100; // Add stop bit to TXByte (which is logical 1)
  TXByte = TXByte << 1; // Add start bit (which is logical 0)
   
  CCTL0 = CCIS0 + OUTMOD0 + CCIE; // Set signal, intial value, enable interrupts
  while ( CCTL0 & CCIE ); // Wait for TX completion
  TACTL = TASSEL_2; // SMCLK, timer off (for power consumption)
}
 
// Timer A0 interrupt service routine
#pragma vector=TIMERA0_VECTOR
__interrupt void Timer_A (void)
{
  CCR0 += Bitime; // Add Offset to CCR0
  if ( BitCnt == 0) // If all bits TXed, disable interrupt
    CCTL0 &= ~ CCIE ;
  else
  {
    CCTL0 |= OUTMOD2; // TX Space
    if (TXByte & 0x01)
      CCTL0 &= ~ OUTMOD2; // TX Mark
    TXByte = TXByte >> 1;
    BitCnt --;
  }
}

// Interrupts from Switch: Toggle LED, increment counter
#pragma vector=PORT1_VECTOR  
 __interrupt void Port_1(void)  
{  
    P1OUT ^= BIT0;  // Toggle P1.0  
    P1IFG &= ~BIT3; // P1.3 interrupt flag cleared
    counter++;  
}

// Update Rate every 60 seconds, called via WDT
#pragma vector=WDT_VECTOR
__interrupt void WATCHDOG_ISR (void){           // interrupt routine
// this routine is called every 32 ms
 wdtCount++; // Counter for rate update (60s)
 
 //update currentRate every 60s = 32ms * 1875
 if(wdtCount == 1875) {
 	if (counter > oldCounter){
      currentRate = counter - oldCounter;
 	}
 	else{ //handle overflow of counter (unsigned int)
 	  currentRate = UINT_MAX - oldCounter + counter +1;
 	}
    oldCounter = counter;
    wdtCount = 0;
 }
}
