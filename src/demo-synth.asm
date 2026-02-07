; This is a demonstration of the MIDI KERNAL for MIDI input
; It shows how MIDI messages are constructed in an interrupt (via MAKEMSG)
; and handed off to a main loop (via GETMSG), and subsequently handled by
; looking at the message data in A,X, and Y
;
; Note that the MIDI KERNAL is included at the bottom of this file, so make
; sure it's available to the assembler.

; VIC Registers
VOLUME      = $900e             ; Volume Register
VOICE       = $900b             ; Middle Voice Register

; Program Memory
LAST_NOTE   = $fc               ; Last note played
LAST_VOICE  = $fe

* = $1600
; Installation routine
#ifdef MAPLIN
#else
Install:    lda #<ISR           ; Set the location of the NMI interrupt service
            sta $0318           ;   routine, which will capture incoming MIDI
            lda #>ISR           ;   messages. Note the lack of SEI/CLI here.
            sta $0319           ;   They would do no good for the NMI.
#endif
            jsr MIDIINIT
            jsr SETIN           ; Prepare hardware for MIDI input
            ldx #0
            ldy #2
InitLoop:   stx LAST_NOTE,y
            dey
            bpl InitLoop
            ; Fall through to Main
 
; Main Loop
; Waits for a complete MIDI message, and then dispatches the message to
; message handlers. This dispatching code and the handlers are pretty barbaric.
; In real life, you probably won't be able to use relative jumps for everything.
#ifdef MAPLIN
Main:       jsr CHKMIDI
            beq NoInput
            jsr MAKEMSG
NoInput:    jsr GETMSG
#else
Main:       jsr GETMSG          ; Has a complete MIDI message been received?
#endif
            bcc Main            ;   If not, just go back and wait
            cmp #ST_NOTEON      ; Is the message a Note On?
            beq NoteOnOffH      ; If so, handle it
            cmp #ST_NOTEOFF     ; Is it a Note Off?
            beq NoteOffH        ; If so, handle it
            bne Main            ; Go back and wait for more

; Note Off Handler            
NoteOffH:   jsr GetNote
            bvs Main
            dey
            lda #0              ; Otherwise, silence the voice
            sta VOICE,y         ; ,,
            sta LAST_NOTE,y
            iny
            jsr CheckBit
            eor #$FF
            and LAST_VOICE
            sta LAST_VOICE
            jmp Main            ; Go get more MIDI

; Note On Handler  
; For the purposes of this demo, we're just accepting notes on any channel.
; In a real application, you'll probably want to check channel numbers, either
; for accept/reject purposes, or to further dispatch messages. That code would
; look something like this:
;     jsr GETCH
;     cmp #LISTEN_CH
;     beq ch_ok
;     jmp Main   
NoteOnOffH: cpx #85             ; Check the range for the VIC-20 frequency
            bcs Main            ;   table. We're allowing note #s 24-85 in
            cpx #24             ;   this simple demo
            bcc Main            ;   ,,
            tya                 ; Put the velocity in A
            beq NoteOffH
            lsr                 ; Shift 0vvvvvvv -> 00vvvvvv
            lsr                 ;       00vvvvvv -> 000vvvvv
            lsr                 ;       000vvvvv -> 0000vvvv
            bne setvol          ; Make sure it's at least 1
            lda #1              ; ,,
setvol:     sta VOLUME          ; Set volume based on high 4 bits of velocity
            jsr GetNote
            bmi Main
            dey
NoteOnH:    txa                 ; Put note number in A
            sta LAST_NOTE,y     ; Store last note for Note Off
            sec                 ; Know carry is set from previous cmp
            sbc #24             ; Subtract 24 to get frequency table index
            cpy #0
            bmi NoteOn
            beq Tenor
            sbc #12
Tenor:      sbc #12
NoteOn:     tax                 ; X is the index in frequency table
            lda FreqTable,x     ; A is the frequency to play
            sta VOICE,y         ; Play the voice
            iny
            jsr CheckBit
            ora LAST_VOICE
            and #$0F
            asl LAST_VOICE
            asl LAST_VOICE
            asl LAST_VOICE
            asl LAST_VOICE
            ora LAST_VOICE
            sta LAST_VOICE
            jmp Main            ; Back for more MIDI messages

GetNote:    cpx #74
            bcs Soprano
            cpx #36
            bcc Alto
            ldy #1
            clv
GetLoop:    php
            txa
            cmp LAST_NOTE,y     ; X is the note. Is it the last one played?
            beq GotNote
            plp
            bmi GotLoop         ; If not, leave it alone
            dey
            bvc GetLoop
GotLoop:    lda LAST_VOICE
            eor #7
            and #7
            jsr GetVoice
            cpy #0
            bpl NoteDone
            lda LAST_VOICE
            lsr
            lsr
            lsr
            lsr
            eor #7
            and #7
            jsr GetVoice
            cpy #0
            bpl NoteDone
            lda #7
            jsr GetVoice
            cpy #0
NoteDone:   jsr sev
            rts
Alto:       ldy #$FF
            bmi CheckNote
Soprano:    ldy #1
CheckNote:  clv
            txa
            cmp LAST_NOTE,y
            beq Playing
            jsr sev
            .byte $80
GotNote:    plp
Playing:    iny
            rts

GetVoice:   cpx #47
            bcs MaybeSop
            and #3
MaybeSop:   cpx #62
            bcc MaybeAlto
            and #6
MaybeAlto:  cpx #35
            bcs MaybeTenor
            and #5
MaybeTenor: cpx #74
            bcc PickVoice
            and #5
PickVoice:  ldy #$FF
            cmp #0
            beq VoiceDone
TestVoice:  iny
            lsr
            bcc TestVoice
VoiceDone:  rts

CheckBit:   lda #$11
            iny
            .byte $80
BitLoop:    asl
            dey
            bne BitLoop
            rts

sev:        pha
            php
            pla
            ora #$40
            pha
            plp
            pla
            rts
            

; NMI Interrupt Service Routine
; If the interrupt is from a byte from the User Port, add it to the MIDI message
; Otherwise, just go back to the normal NMI (to handle STOP/RESTORE, etc.)
ISR:        pha                 ; NMI does not automatically save registers like
            txa                 ;   IRQ does, so that needs to be done
            pha                 ;   ,,
            tya                 ;   ,,
            pha                 ;   ,,
            jsr CHKMIDI         ; Is this a MIDI-based interrupt?
            bne midi            ;   If so, handle MIDI input
            jmp $feb2           ; Back to normal NMI, after register saves
midi:       jsr MAKEMSG         ; Add the byte to a MIDI message
            jmp $ff56           ; Restore registers and return from interrupt

; Frequency numbers VIC-20
; 135 = Note #48
; Between 48 and 85
#ifndef PAL ;NTSC timings
FreqTable:  .byte 135,143,147,151,159,163,167,175,179,183,187,191
            .byte 195,199,201,203,207,209,212,215,217,219,221,223
            .byte 225,227,228,229,231,232,233,235,236,237,238,239
            .byte 240,241
#else       ;PAL timings
FreqTable:  .byte 128,134,141,147,153,159,164,170,174,179,183,187,
            .byte 191,195,198,201,204,207,210,213,215,217,219,221,
            .byte 223,225,227,228,230,231,232,234,235,236,237,238,
            .byte 239,240
#endif

#include "midikernal.asm"
