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

#ifdef PAL
#define FLOORADJ 1
#else
#define FLOORADJ 0
#endif
#ifdef TRUEFREQ
#define CEILADJ 1
#else
#define CEILADJ 0
#endif
#undef REVERSE_REGISTERS
#define REVERSE_REGISTERS
#undef NOTE_PRIORITY
#ifdef HIGH_NOTE_PRIORITY
#undef LOW_NOTE_PRIORITY
#define NOTE_PRIORITY
#endif
#ifdef LOW_NOTE_PRIORITY
#define NOTE_PRIORITY
#endif

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
            ldx #2
            ldy #0
InitLoop:   sty LAST_NOTE,x
            dex
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
NoteOffH:   tya
#ifdef PER_CHANNEL_NOTE_OFF
            pha
            jsr GETCH
            tay
            pla
            cmp LastTable,y
            beq KeepMute
            ldx LastTable,y
#ifdef HIGH_NOTE_PRIORITY
            beq KeepMute
#else
            bmi KeepMute
#endif
            txa
KeepMute:   tay
            jsr GetNote
#else
            jsr GetNote
            bvc KeepMute
            jsr GETCH
            tay
            cmp LastTable,y
            beq Main
            lda LastTable,y
#ifdef HIGH_NOTE_PRIORITY
            beq Main
#else
            bmi Main
#endif
            tay
            jsr GetNote
KeepMute:
#endif
            jsr GETCH
            tay
#ifdef HIGH_NOTE_PRIORITY
            lda #0
#else
            lda #$ff
#endif
            sta LastTable,y
            bvs Main
            dex
            lda #0              ; Otherwise, silence the voice
            sta VOICE,x         ; ,,
            sta LAST_NOTE,x
            inx
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
NoteOnOffH: cpy #85-CEILADJ     ; Check the range for the VIC-20 frequency
            bcs Main            ;   table. We're allowing note #s 24-85 in
            cpy #24+FLOORADJ    ;   this simple demo
            bcc Main            ;   ,,
            txa                 ; Put the velocity in A
            beq NoteOffH
            lsr                 ; Shift 0vvvvvvv -> 00vvvvvv
            lsr                 ;       00vvvvvv -> 000vvvvv
            lsr                 ;       000vvvvv -> 0000vvvv
            bne setvol          ; Make sure it's at least 1
            lda #1              ; ,,
setvol:     sta VOLUME          ; Set volume based on high 4 bits of velocity
NoteOnH:    tya                 ; Put note number in A
            pha
            jsr GETCH
            tay
            pla
#ifdef NOTE_PRIORITY
            cmp LastTable,y
#ifdef HIGH_NOTE_PRIORITY
            bcs KeepNote
#else
            bcc KeepNote
#endif
            tay
            jsr GetNote
            bvs NoMute
            dex
            lda #0
            sta VOICE,x
            sta LAST_NOTE,x
NoMute:     jsr GETCH
            tay
            lda LastTable,y
#endif
KeepNote:   sta LastTable,y
            tay
            jsr GetNote
            dex
            tya
            sta LAST_NOTE,x     ; Store last note for Note Off
            sec                 ; Know carry is set from previous cmp
            sbc #24             ; Subtract 24 to get frequency table index
            cpx #0
            bmi NoteOn
            beq Tenor
            sbc #12
Tenor:      sbc #12
NoteOn:     tay                 ; Y is the index in frequency table
            lda FreqTable,y     ; A is the frequency to play
            sta VOICE,x         ; Play the voice
            inx
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

GetNote:    cpy #74-CEILADJ
            bcs Soprano
            cpy #36+FLOORADJ
            bcc Alto
            ldx #1
            clv
GetLoop:    php
            tya
            cmp LAST_NOTE,x     ; Y is the note. Is it the last one played?
            beq GotNote
            plp
            bmi GotLoop         ; If not, leave it alone
            dex
            bvc GetLoop
GotLoop:    lda LAST_VOICE
            eor #7
            and #7
            jsr GetVoice
            cpx #0
            bpl NoteDone
            lda LAST_VOICE
            lsr
            lsr
            lsr
            lsr
            eor #7
            and #7
            jsr GetVoice
            cpx #0
            bpl NoteDone
            lda #7
            jsr GetVoice
            cpx #0
NoteDone:   jsr sev
            rts
Alto:       ldx #$FF
            bmi CheckNote
Soprano:    ldx #1
CheckNote:  clv
            tya
            cmp LAST_NOTE,x
            beq Playing
            jsr sev
            .byte $80
GotNote:    plp
Playing:    inx
            rts

GetVoice:   cpy #47+FLOORADJ
            bcs MaybeSop
            and #3
MaybeSop:   cpy #62-CEILADJ
            bcc MaybeAlto
            and #6
MaybeAlto:  cpy #35+FLOORADJ
            bcs MaybeTenor
            and #5
MaybeTenor: cpy #74-CEILADJ
            bcc PickVoice
            and #5
PickVoice:  ldx #$FF
            cmp #0
            beq VoiceDone
TestVoice:  inx
            lsr
            bcc TestVoice
VoiceDone:  rts

CheckBit:   lda #$11
            inx
            .byte $80
BitLoop:    asl
            dex
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
#ifndef TRUEFREQ                ; Below are the "official" numbers
; 135 = Note #48
; Between 48 and 85
#ifndef PAL ;NTSC timings
FreqTable:  .byte 135,143,147,151,159,163,167,175,179,183,187,191
            .byte 195,199,201,203,207,209,212,215,217,219,221,223
            .byte 225,227,228,229,231,232,233,235,236,237,238,239
            .byte 240,241
#else       ;PAL timings
; http://sleepingelephant.com/ipw-web/bulletin/bb/viewtopic.php?p=43437#p43437
FreqTable:  .byte 255,134,141,147,153,159,164,170,174,179,183,187
            .byte 191,195,198,201,204,207,210,212,215,217,219,221
            .byte 223,225,226,228,230,231,232,234,235,236,237,238
            .byte 239,240
#endif
#else                           ; Derived from pp.216-217 of the Prog Ref Manual
#ifndef PAL ;NTSC timings
FreqTable:  .byte 133,140,146,152,158,163,169,173,178,182,186,190
            .byte 194,197,201,204,207,209,212,214,217,219,221,223
            .byte 224,226,228,229,231,232,233,235,236,237,238,239
            .byte 240,241
#else       ;PAL timings
FreqTable:  .byte 123,130,137,144,150,156,161,167,172,176,181,185
            .byte 189,193,196,199,202,205,208,211,213,216,218,220
            .byte 222,224,226,227,229,230,232,233,234,235,236,237
            .byte 238,239
#endif
#endif
            .byte 0
#ifdef HIGH_NOTE_PRIORITY
LastTable:  .dsb 16,0
#else
LastTable:  .dsb 16,255
#endif

#include "midikernal.asm"
