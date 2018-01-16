
	processor 6502
	include "include/vcs.h"
	include "include/macro.h"

; TODO Implement Bird AI and gamemode where p2 can be Bird
; implement collision
; implement room loading where each transition takes you to a different room
; implement level counter
; implement lives counter
; implement room amount to ocean based on level

PAL = 0
NTSC = 1

SYSTEM = NTSC   ; change this to PAL or NTSC

; ---------- Variables
	SEG.U vars
	ORG $80 ; start of RAM

FRAMECOUNT ds 1 ; animation counter location

Score ds 1 ; holdds 2 digit score, sotred as BCD
Timer ds 1

; digit graphic data

DigitOnes ds 2 ; DigitiOnes = score, DigitOnes+1 = timer
DigitTens ds 2

; graphic data to be put into PF1
ScoreGfx ds 1
TimerGfx ds 1

Temp ds 1

; object X positions in $89-8C
ObjectX:        ds 4    ; player0, player1, missile0, missile1

; object Y positions in $8D-90
ObjectY:        ds 4    ; player0, player1, missile0, missile1

; DoDraw storage in $91-92
TurtleDraw:      ds 1    ; used for drawing player0
BirdDraw:        ds 1    ; used for drawing player1

; DoDraw Graphic Pointer in $93-94
TurtlePtr:       ds 2    ; used for drawing player0
BirdPtr:         ds 2    ; used for drawing player1

; map pointer used for map rendering
MapPtr0:         ds 2    ; used for drawing map
MapPtr1:         ds 2    ; used for drawing map
MapPtr2:         ds 2    ; used for drawing map
	; ---------- Constants

	SEG.U constants

TIMETOCHANGE = 20 ; speed of animation
; height of the arena (gameplay area).  Since we're using a 2 line kernel,
    ; actual height will be twice this.  Also, we're using 0-89 for the
    ; scanlines so actual height is 180 = 90*2
PFHEIGHT = 89 ; 180 scanlines of playfield h
NULL = 0 ; just 0

;===============================================================================
; Define Start of Cartridge
;===============================================================================

	SEG CODE ; define code segment
; ----------
	ORG $F000 ; 4k carts start at $F000

Reset
	; clear all ram and registers
	ldx #0
	lda #0
Clear
	; CLEAN_START is a macro found in macro.h
  ; it sets all RAM, TIA registers and CPU registers to 0
  CLEAN_START

	; Init, run once only!

	; set up srptie pos
	ldx #0
	stx ObjectX
  ldx #8
  stx ObjectX+1
  ldy #$30
  sty ObjectY
  sty ObjectY+1

	jsr PlayIntroSong

StartOfFrame
	; start of new frame
	inc FRAMECOUNT
	jsr VerticalSync
	jsr VerticalBlank
	jsr Picture
	jsr Overscan
	jmp StartOfFrame

VerticalSync
	; start vblank processing
	lda #2
	ldx #49
	sta WSYNC
	sta VSYNC
	stx TIM64T  ; set timer to go off in 41 scanlines (49 * 64) / 76
	sta CTRLPF  ; D1=1, playfield now in SCORE mode
	sta WSYNC
	sta WSYNC ; 3 scanlines of WSYNC

	lda #0
	sta PF0
	sta PF1
	sta GRP0
	sta GRP1
	sta GRP0
	sta WSYNC
	sta VSYNC
Sleep12 ; jsr here to sleep for 12 cycles
	rts

VerticalBlank
	jsr PositionObjects
	jsr SetObjectColours
	jsr PrepScoreForDisplay
	rts

Picture
	; turn on display
	sta WSYNC ; Wait for SYNC (halts CPU until end of scanline)
	lda INTIM ; check vertical sync timer
	bne Picture
	sta VBLANK ; turn on the display

; draw score
	ldx #5
scoreLoop
	ldy DigitTens ; get the tens digit offset for the score
	lda DigitGfx,y
	and #$F0 ; remove the graphics for the ones digit
	sta ScoreGfx ; and save it
	ldy DigitOnes ; get the ones digit offset foir the score
	lda DigitGfx,y ; use it to load the digit gfx
	and #$0F ; remove 10s digit
	ora ScoreGfx ; merge with tens digit and gfx
	sta ScoreGfx ; and save it
	sta WSYNC
;---------------------------------------
	sta PF1 ; update pf1 for score display
	ldy DigitTens+1 ; get the left digit offset
	lda DigitGfx,y ; use it to load
	and #$F0 ; remove the gfx for the ones digit
	sta TimerGfx ; and save it
	ldy DigitOnes+1 ; get the ones offset from the timer
	lda DigitGfx,y ; use it to load gfx
	and #$0F ; remove the gfx for the tens digit
	ora TimerGfx ; merge
	sta TimerGfx ; and save it
	jsr Sleep12 ; waste some cycles
	sta PF1 ; update playfield for timer display
	ldy ScoreGfx ; preload for next line
	sta WSYNC ; wait for the end of scanline
;---------------------------------------
	sty PF1 ; update playfield for the score display
	inc DigitTens ; advance to the next line of gfx data
	inc DigitTens+1 ; advance to the next line of gfx data
	inc DigitOnes ; advance to the next line of gfx data
	inc DigitOnes+1 ; advance to the next line of gfx data
	jsr Sleep12
	dex ; decrease loop counter
	sta PF1 ; update playfield
	bne scoreLoop ; if dex != 0 then loop
	sta WSYNC
;---------------------------------------
	stx PF1 ; blank out PF1 - x must be zero here!
	sta WSYNC

	sta WSYNC ; space between score and arena

	lda #1              ; 2  2
	sta CTRLPF          ; 3  5 - turn off SCORE mode and turn on REFLECT

	; now we load the map ptrs
	lda #<(Room1LayoutPF0) ; store room1layout in MapPtr as a ptr
	sta MapPtr0
	lda #>(Room1LayoutPF0) ;
	sta MapPtr0+1 ; store the rest in MapPtr+1

	lda #<(Room1LayoutPF1) ; store room1layout in MapPtr as a ptr
	sta MapPtr1
	lda #>(Room1LayoutPF1) ;
	sta MapPtr1+1 ; store the rest in MapPtr+1

	lda #<(Room1LayoutPF2) ; store room1layout in MapPtr as a ptr
	sta MapPtr2
	lda #>(Room1LayoutPF2) ;
	sta MapPtr2+1 ; store the rest in MapPtr+1

	; Do 192 scanlines of colour-changing (our picture)
	ldy #PFHEIGHT ; draw the screen for 192 lines
	ldx #0
	stx Temp ; store map counter in temp
pfLoop
	; continuation of line 2 of the 2LK
	; this precalculates data that's used on line 1 of the 2LK
	lda #TURTLEHEIGHT-1 ; height of turtle sprite - 1
	dcp TurtleDraw ; Decrement TurtleDraw and compare with height
	bcs DoDrawGrp0 ; if carry is set then turtle is on current scanline
	lda #0 ; otherwise use 0 to turn off p0
	.byte $2C ; $2C = BIT with absolute addressing, trick that
          	;        causes the lda (Turtle),y to be skipped
DoDrawGrp0 ;
	lda (TurtlePtr),y ; load shape
	sta WSYNC ; wait for line

	sta GRP0 ; update player0 to draw turtle

	; draw playfield
	tya ; transfer y to a
	ldy Temp ; load y with map counter
	sta Temp ; store y for now

	lda (MapPtr0),y ; playfiled pattern test
	sta PF0
	lda (MapPtr1),y ; playfiled pattern test
	sta PF1
	lda (MapPtr2),y ; playfiled pattern test
	sta PF2
	iny ; increment y
	lda Temp ; load back old y
	sty Temp ; store new map counter
	tay ; and transfer it back

	; precalculate date for next line
	lda #TURTLEHEIGHT-1 ; height of gfx
	dcp BirdDraw ; decrement BirdDraw
	bcs DoDrawGrp1
	lda #0
	.byte $2C
DoDrawGrp1
	lda (BirdPtr),y
	sta WSYNC
	; start of line 2 of the 2LK
	sta GRP1

	dey ; decrease the loop counter
	bne pfLoop ; branch if more left to draw

	lda #0
	sta PF0
	sta PF1
	sta PF2

	rts ; return

	; 30 scanlines of overscan
Overscan
	sta WSYNC
  lda #2
	sta VBLANK
	lda #32 ; set time for 27 scanlines 32 = ((27 * 76) / 64)
	sta TIM64T ; timer will go off after 27 scanlines

	; game logic call
	jsr ProcessJoystick

	lda #1
overscanLoop
	sta WSYNC
	lda INTIM ; check timer
	bpl overscanLoop
	rts


ProcessJoystick
; game logic here
	lda  SWCHA ; input registr
	asl  ; test bit 0, left joy - right input
	bcs Player1RightNotPressed ; this operation sets the carry for the fromer bit that fell off
	; right pressed code
	ldx ObjectX
	inx
	cpx #160
	bne SaveX ; save X if we're not at the edge
	ldx #0 ; warp to other edge
SaveX
	stx ObjectX
	ldx #1
	stx REFP0 ; makes turtle image face right
Player1RightNotPressed
	asl ; test bit 1, left joy - left input
	bcs Player1LeftNotPressed
	; left pressed code
	ldx ObjectX
	dex
	cpx #255 ; test for edge of screen
	bne SaveX2
	ldx #159 ; warp to toher side
SaveX2
	stx ObjectX
	ldx #0
	stx REFP0 ; makes turtle image face left
Player1LeftNotPressed
	asl ; test bit 1, left joy - down input
	bcs Player1DownNotPressed
	; left pressed code
	ldx ObjectY
	dex
	cpx #255
	bne SaveY
	ldx #PFHEIGHT
SaveY
	stx ObjectY
Player1DownNotPressed
	asl ; test bit 2, left joy - up input
	bcs Player1UpNotPressed
	; left pressed code
	ldx ObjectY
	inx
	cpx PFHEIGHT+1
	bne SaveY2
	ldx #0
SaveY2
	stx ObjectY
Player1UpNotPressed
	rts

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

SetObjectColours
	ldx #3 ; we're going to set 4 colours
	ldy #3 ;
	lda SWCHB ; read the state of the console switches
	and #%00001000  ; test state of D3, the TV Type switch
	bne SOCloop ; if D3=1 then use colour
	ldy #7 ; else b&w entries in table
SOCloop
	lda Colours,y ; get the colour or b&w value
	sta COLUP0,x ; and set it
	dey ; decrease y
	dex ; decrease x
	bpl SOCloop ; branch if positive
	rts ; return

PrepScoreForDisplay
	; for testing purposes, change the values in Timer and Score
	inc Timer ; inc timer by 1
	bne PSFDskip ; branch if not 0
	inc Score ; inc score by 1 if Timer just rolled to 0
PSFDskip
	ldx #1 ; use x as the loop counter for PSFDloop
PSFDloop
	lda Score,x ; load A with timer or Score
	and #$0F ; remove the tens digit
	sta Temp ; store a into temp
	asl ; shift left * 2
	asl ; shfit left * 4
	adc Temp ; add with carry in Temp * 5
	sta DigitOnes,x ; store a in DigitOnes+1 or DigitOnes
	lda Score,x ; load a with timer or score
	and #$F0 ; remove the ones digit
	lsr ; shift right / 2
	lsr ; shift right / 2
	sta Temp ; store a into temp
	lsr ; shift right / 8
	lsr ; shift right / 16
	adc Temp ; add with carry in temp / 16 * 5
	sta DigitTens,x
	dex ; dec x by 1
	bpl PSFDloop ; branch positive to loop
	rts

PositionObjects
	ldx #1 ; position objects 0-1: player0 and player1
POloop
	lda ObjectX,x       ; get the object's X position
	jsr PosObject       ; set coarse X position and fine-tune amount
	dex                 ; DEcrement X
	bpl POloop          ; Branch PLus so we position all objects
	sta WSYNC           ; wait for end of scanline
	sta HMOVE           ; use fine-tune values to set final X positions

	; every other frame load different animation
	; to get odd frames and framecount with 1
	;lda #0
	;sta Temp
	;lda FRAMECOUNT
	;and #$1
	;bne TurtleFrame1
	;jmp TurtleFrame2 ; TODO this can be made much better
TurtleFrame1
	; TurtleDraw = PFHEIGHT + TURTLEHEIGHT - Y position
	lda #(PFHEIGHT + TURTLEHEIGHT)
	sec
	sbc ObjectY
	sta TurtleDraw

	; TurtlePtr = PFHEIGHT + TURTLEHEIGHT - 1 - Y position
	lda #<(TurtleSprite + TURTLEHEIGHT - 1) ; because sprite is upside down
	sec
	sbc ObjectY
	sta TurtlePtr
	lda #>(TurtleSprite + TURTLEHEIGHT - 1)
	sbc #0
	sta TurtlePtr+1
	;jmp BirdFrame1

BirdFrame1
	; BirdDraw = PFHEIGHT + BIRDHEIGHT - Y position
	lda #(PFHEIGHT + BIRDHEIGHT)
	sec
	sbc ObjectY+1
	sta BirdDraw

	; BirdPtr = TurtleSprite + TURTLEHEIGHT - 1 - Y position
	lda #<(BirdSprite + BIRDHEIGHT - 1)
	sec
	sbc ObjectY+1
	sta BirdPtr
	lda #>(BirdSprite + BIRDHEIGHT - 1)
	sbc #0
	sta BirdPtr+1

	; use Difficulty Switches to test how Vertical Delay works
	ldx #0
	stx VDELP0      ; turn off VDEL for player0
	stx VDELP1      ; turn off VDEL for player1
	inx
	bit SWCHB       ; state of Right Difficult in N (negative flag)
									; state of Left Difficult in V (overflow flag)
	bvc LeftIsB
	stx VDELP0      ; Left is A, turn on VDEL for player0
LeftIsB
	bpl RightIsB
	stx VDELP1      ; Right is A, turn on VDEL for player1
RightIsB
	rts

	;===============================================================================
	; PosObject
	;----------
	; subroutine for setting the X position of any TIA object
	; when called, set the following registers:
	;   A - holds the X position of the object
	;   X - holds which object to position
	;       0 = player0
	;       1 = player1
	;       2 = missile0
	;       3 = missile1
	;       4 = ball
	; the routine will set the coarse X position of the object, as well as the
	; fine-tune register that will be used when HMOVE is used.
	;===============================================================================
PosObject
	sec
	sta WSYNC
DivideLoop
	sbc #15        ; 2  2 - each time thru this loop takes 5 cycles, which is
	bcs DivideLoop ; 2  4 - the same amount of time it takes to draw 15 pixels
	eor #7         ; 2  6 - The EOR & ASL statements convert the remainder
	asl            ; 2  8 - of position/15 to the value needed to fine tune
	asl            ; 2 10 - the X position
	asl            ; 2 12
	asl            ; 2 14
	sta HMP0,X  ; 5 19 - store fine tuning of X
	sta RESP0,X    ; 4 23 - set coarse X position of object
	rts            ; 6 29

Colours:
	.byte $C6   ; green      - goes into COLUP0, color for player1 and missile0
	.byte $86   ; blue       - goes into COLUP1, color for player0 and missile1
	.byte $46   ; red        - goes into COLUPF, color for playfield and ball
	.byte $00   ; black      - goes into COLUBK, color for background
	.byte $0E   ; white      - goes into COLUP0, B&W for player0 and missile0
	.byte $06   ; dark grey  - goes into COLUP1, B&W for player1 and missile1
	.byte $0A   ; light grey - goes into COLUPF, B&W for playfield and ball
	.byte $00   ; black      - goes into COLUBK, B&W for background

; Sprite data
TurtleSprite:
	.byte %10000001
	.byte %11000011
	.byte %00111100
	.byte %01111110
	.byte %00111100
	.byte %01111110
	.byte %01011010
	.byte %10000001
TURTLEHEIGHT = * - TurtleSprite

TurtleSprite2:
	.byte %01000010
	.byte %11000011
	.byte %00111100
	.byte %00111100
	.byte %00111100
	.byte %01111110
	.byte %01011010
	.byte %01000010
TURTLEHEIGHT2 = * - TurtleSprite2

BirdSprite:
	.byte %00000000
	.byte %10011001
	.byte %01011010
	.byte %10100101
	.byte %10011001
	.byte %00011000
	.byte %00011000
	.byte %00100100
BIRDHEIGHT = * - BirdSprite

	align 256
DigitGfx:
	.byte %01110111
	.byte %01010101
	.byte %01010101
	.byte %01010101
	.byte %01110111

	.byte %00010001
	.byte %00010001
	.byte %00010001
	.byte %00010001
	.byte %00010001

	.byte %01110111
	.byte %00010001
	.byte %01110111
	.byte %01000100
	.byte %01110111

	.byte %01110111
	.byte %00010001
	.byte %00110011
	.byte %00010001
	.byte %01110111

	.byte %01010101
	.byte %01010101
	.byte %01110111
	.byte %00010001
	.byte %00010001

	.byte %01110111
	.byte %01000100
	.byte %01110111
	.byte %00010001
	.byte %01110111

	.byte %01110111
	.byte %01000100
	.byte %01110111
	.byte %01010101
	.byte %01110111

	.byte %01110111
	.byte %00010001
	.byte %00010001
	.byte %00010001
	.byte %00010001

	.byte %01110111
	.byte %01010101
	.byte %01110111
	.byte %01010101
	.byte %01110111

	.byte %01110111
	.byte %01010101
	.byte %01110111
	.byte %00010001
	.byte %01110111

	.byte %00100010
	.byte %01010101
	.byte %01110111
	.byte %01010101
	.byte %01010101

	.byte %01100110
	.byte %01010101
	.byte %01100110
	.byte %01010101
	.byte %01100110

	.byte %00110011
	.byte %01000100
	.byte %01000100
	.byte %01000100
	.byte %00110011

	.byte %01100110
	.byte %01010101
	.byte %01010101
	.byte %01010101
	.byte %01100110

	.byte %01110111
	.byte %01000100
	.byte %01100110
	.byte %01000100
	.byte %01110111

	.byte %01110111
	.byte %01000100
	.byte %01100110
	.byte %01000100
	.byte %01000100

; the room table holds pf information for each 1/2 scanline as a byte. 45 bytes
; All rooms require PF1 and PF2 tables as well
Room1LayoutPF0:
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %11111111
	.byte %11111111
	.byte %01111100
Room1LayoutPF1:
	REPEAT PFHEIGHT
	.byte %11111111
	REPEND
Room1LayoutPF2:
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %01000111
	.byte %11111111
	.byte %11111111
	.byte %01111100
	.byte %11111111
	.byte %11111111
	.byte %01111100


; Table holding all the room start addresses next to each other
RoomTable:
	.word Room1LayoutPF0
	.word Room1LayoutPF1
	.word Room1LayoutPF2

	;------------------------------------------------------------------------------

	ORG $FFFA ; set address to 6507 Interrupt Vectors

	;===============================================================================
	; Define End of Cartridge
	;===============================================================================
InterruptVectors
	.word Reset          ; NMI
	.word Reset          ; RESET
	.word Reset          ; IRQ
END
