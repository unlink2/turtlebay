
	processor 6502
	include "include/vcs.h"
	include "include/macro.h"

PAL = 0
NTSC = 1

SYSTEM = NTSC   ; change this to PAL or NTSC

; ---------- Variables
	SEG.U vars
	ORG $80 ; start of RAM

PATTERN ds 1 ; storage location
FRAMECOUNT ds 1 ; animation counter location
SPR1X ds 1 ; x pos si delay when drawing
SPR1Y ds 1 ; y pos is scanline
SPR2X ds 1
SPR2Y ds 1

	SEG ; end of uninitialized segment - start of ROM binary
	; ---------- Constants

	SEG.U constants

TIMETOCHANGE = 20 ; speed of animation
SPRITE1H = 16
NULL = 0 ; just 0

	SEG
; ----------
	ORG $F000

Reset

	; clear all ram and registers
	ldx #0
	lda #0
Clear
	sta 0,x
	inx
	bne Clear

	; Init, run once only!
	lda #0
	sta PATTERN ; The binary PF 'pattern'

	lda #$45
	sta COLUPF ; set colour of playfield
	ldy #0 ; speed counter

	lda #%00000001
	sta CTRLPF ; reflect playfield

	; srptie colours
	lda #$69
	sta COLUP0
	lda #$67
	sta COLUP1

	; set up srptie pos
	lda #20
	sta SPR1X
	lda #15
	sta SPR1Y

	lda #30
	sta SPR2X
	lda #15
	sta SPR2Y

	jsr PlayIntroSong

StartOfFrame
	; start of new frame
	; start vblank processing
	inc FRAMECOUNT
	lda #0
	sta VBLANK

	lda #2
	sta VSYNC

	sta WSYNC
	sta WSYNC
	sta WSYNC ; 3 scanlines of WSYNC

	lda #0
	sta VSYNC


	; 37 scanlines of VBLANK
	ldx #0
VerticalBlank
	sta WSYNC
	inx
	cpx #37
	bne VerticalBlank

; game logic here
	lda  SWCHA ; input registr
	asl  ; test bit 0, left joy - right input
	bcs Player1RightNotPressed ; this operation sets the carry for the fromer bit that fell off
	; right pressed code
	ldx SPR1X
	inx
	stx SPR1X
Player1RightNotPressed
	asl ; test bit 1, left joy - left input
	bcs Player1LeftNotPressed
	; left pressed code
	ldx SPR1X
	dex
	stx SPR1X
Player1LeftNotPressed
	asl ; test bit 1, left joy - down input
	bcs Player1DownNotPressed
	; left pressed code
	ldx SPR1Y
	inx
	stx SPR1Y
Player1DownNotPressed
	asl ; test bit 2, left joy - up input
	bcs Player1UpNotPressed
	; left pressed code
	ldx SPR1Y
	dex
	stx SPR1Y
Player1UpNotPressed



	; Do 192 scanlines of colour-changing (our picture)
	ldx 0
	; set up PF to display a wall around the game field
	lda #%11111111
	sta PF0
	sta PF1
	sta PF2
Picture
	stx COLUBK ; ranbow effect on background

Top8LinesWall
	sta WSYNC
	inx
	cpx #8 ; line 8?
	bne Top8LinesWall ; No? Another loop

	; now we change the lines
	lda #%00010000 ; PF0 is mirrored <--- direction, low 4 bits ignored
	sta PF0
	lda #0
	sta PF1
	sta PF2

	; again, we don't bother writing PF0-PF2 every scanline - they never change!
	ldy #0 ; load y with 0, we use y to count sprite tables
MiddleLinesWall
	; push y to save for later
	lda #1 ; load an odd number into a
	and FRAMECOUNT ; and it with framecount to see if even or odd frame count
	; only do sprites on odd frames 0 == even 1 == odd
	cmp NULL
	beq SpriteDone

	; sprite stuff
	cpx SPR1Y
	bcc SpriteReset
	cpy #SPRITE1H
	beq SpriteReset ; if sprites are bigger than 32, we are done!
	; SLEEP 20

	lda SPR1X

	sec ; Set the carry flag so no borrow will be applied during the division.
.divideby15 ; Waste the necessary amount of time dividing X-pos by 15!
	sbc #15
	bcs .divideby15

	sta RESP0

	lda TurtleSprite,y
	sta GRP0 ; modify sprite 0 shape
	iny

	jmp SpriteDone
SpriteReset
	; reset sprite registers to 0
	lda #0
	sta GRP0
SpriteDone

	sta WSYNC

	inx
	cpx #184
	bne MiddleLinesWall

	; Finally, our bottom 8 scanlines - the same as the top 8
	; AGAIN, we aren't going to bother writing PF0-PF2 mid scanline!

	lda #%11111111
	sta PF0
	sta PF1
	sta PF2

Bottom8LinesWall
	; make sure sprite registers are cleared here!
	lda 0
	sta GRP0
	sta GRP1

	sta WSYNC
	inx
	cpx #192
	bne Bottom8LinesWall

	; ---------------

	lda #%01000010
	sta VBLANK ; end of screen - start blanking



	; 30 scanlines of overscan
	lda #0
	sta PF0
	sta PF1
	sta PF2

	ldx #0
Overscan
	sta WSYNC
  inx
	cpx #30
	bne Overscan

	jmp StartOfFrame

; Plays the Intro noise
PlayIntroSong
	lda #2
	sta AUDC0
	sta AUDF0
	sta AUDV0

	jsr ClearSong

	rts

ClearSong
	; song done, now we quit
	lda #0
	sta AUDC0
	sta AUDF0
	sta AUDV0
	rts

; use jsr to jump here
; number instructions until return is passed in as y
; destroys y
DelayLoop
	dey
	bne DelayLoop
	rts

; This is a table that lets us divide by 15 for sprite positioning
; -> hardcoded table is a lot faster than computing it!
Divide15
.POS SET 0
	REPEAT 160
	.byte (.POS / 15) + 1
.POS SET .POS + 1
	REPEND

; Sprite data
TurtleSprite
	.byte  %00011000
	.byte  %01100100
	.byte  %11000011
	.byte  %00001111
	.byte  %00011001
	.byte  %00110000
	.byte  %00110110
	.byte  %01111111
	.byte  %01111111
	.byte  %01111111
	.byte  %01110000
	.byte  %00110000
	.byte  %00111000
	.byte  %00011110
	.byte  %00001111
	.byte  %00000011

	.byte  %00001100
	.byte  %00010010
	.byte  %11100011
	.byte  %11111001
	.byte  %11001100
	.byte  %10000110
	.byte  %10110110
	.byte  %11111111
	.byte  %11111111
	.byte  %11111111
	.byte  %00000111
	.byte  %00000110
	.byte  %00001110
	.byte  %00111100
	.byte  %11111000
	.byte  %11100000

	;------------------------------------------------------------------------------

	ORG $FFFA

InterruptVectors
	.word Reset          ; NMI
	.word Reset          ; RESET
	.word Reset          ; IRQ
END
