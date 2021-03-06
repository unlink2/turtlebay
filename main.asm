
	processor 6502
	include "include/vcs.h"
	include "include/macro.h"

; TODO Implement Bird AI and gamemode where p2 can be Bird
; implement collision
; implement room loading where each transition takes you to a different room
; implement level counter
; implement lives counter
; implement room amount to ocean based on level
; implement way for turtle to shoot in the direction pressed
; when bird is hit it loses control for a few frames and is pushed back
; collision detection based on just a few sample pixels. edges and center of edges?
; and the current x and y position
; each ball collection will reduce score by 1, when score is 0 -> go to next map and reduce lvl counter
; load a new random map
; maybe even randomize each part of the map?
; at a certain level make it so that bird duplicates
; TODO fix ball
; make ball change positon after 10 seconds

PAL = 0
NTSC = 1
SECAM = 2

SYSTEM = NTSC   ; change this to PAL or NTSC or SECAM

; ---------- Variables
	SEG.U vars
	ORG $80 ; start of RAM

Framecount ds 1 ; animation counter location

Score ds 1 ; holdds 2 digit score, sotred as BCD
Timer ds 1 ;
Level: ds 1 ; level counter
Lives: ds 1 ; live counter

; digit graphic data

DigitOnes ds 3 ; DigitiOnes = score, DigitOnes+1 = timer DigitOnes+2 = level
DigitTens ds 3

; graphic data to be put into PF1
ScoreGfx ds 1
TimerGfx ds 1

Temp ds 4 ; 4 bytes of temp storage

; object X positions in $89-8C
ObjectX:        ds 5    ; player0, player1, missile0, missile1, ball

; object Y positions in $8D-90
ObjectY:        ds 5    ; player0, player1, missile0, missile1, ball

; DoDraw storage in $91-92
TurtleDraw:      ds 1    ; used for drawing player0
BirdDraw:        ds 1    ; used for drawing player1
M0Draw: ds 1

; DoDraw Graphic Pointer in $93-94
TurtlePtr:       ds 2    ; used for drawing player0
BirdPtr:         ds 2    ; used for drawing player1

; used for Bird AI to keep track of movement
BirdAICounter ds 1
BirdLeftRightStatus ds 1
BirdUpDownStatus ds 1

; map pointer used for map rendering
MapPtr0:         ds 2    ; used for drawing map
MapPtr1:         ds 2    ; used for drawing map
MapPtr2:         ds 2    ; used for drawing map
; map counter for each PF, currently all of those are the same
CurrentMap: ds 3 ; map counter - must increment by 6 for new map to fully load
RandMap: ds 1 ; map timer, increments by one each frame until MAPCOUNT is reached
; then resets to 0. used to get a random map

MapsCleared: ds 1 ; amount of clreaded maps this level

AnimationTimer ds 4 ; animation timer for p0, p1, m0, m1

PreviousX ds 4
PreviousY ds 4

M0RespawnTimer ds 1 ; ball will change location after x secnds (each time Framecount rolls over this is dec)
GameState ds 1 ; gamestate. 0 = playing 1 = intro 2 = ocean reached animation
ColourCycle ds 1 ; used for pause screen

; Music Pointers
; these point to memory locations that are to be played when music is on
; music should be input in reverse order because of the way the counter works!
SoundEnabled ds 1 ; set to how many frames are to be played
SoundEnabled2 ds 1
SoundTrackPtr ds 2 ; points to sound to be played
SoundTrackPtr2 ds 2 ; points to sound to be played
SoundSpeed ds 1 ; speed of sound
SoundControl ds 2 ; sound control
SoundControl2 ds 2 ; sound control

; used by Random for an 8 bit random number
Rand8 ds 1

	; ---------- Constants

	SEG.U constants

TIMETOCHANGE = 20 ; speed of animation
; height of the arena (gameplay area).  Since we're using a 2 line kernel,
    ; actual height will be twice this.  Also, we're using 0-89 for the
    ; scanlines so actual height is 180 = 90*2
PFHEIGHT = 89 ; 180 scanlines of playfield h
NULL = 0 ; just 0
P0STARTX = $4D
P0STARTY = $32
P1STARTX = 0
P1STARTY = 0
M0HEIGHT = 4
M0RESPAWNT = 255
MAPCOUNT = 10
OFFSETPERMAP = 6

; music volumes

; music speed
;S_FULLSPEED = 0 ; no delay at all
;S_HALFSPEED = $1 ; and fore very other frame
;S_QUARTERSPEED = %11111 ; and for every 4th frame

;===============================================================================
; Define Start of Cartridge
;===============================================================================

	SEG CODE ; define code segment
; ----------
	ORG $F800 ; 4k carts start at $F000

; Init, run once only!
Start
Clear
	; clear all ram and registers
	ldx #0
	lda #0
	; CLEAN_START is a macro found in macro.h
  ; it sets all RAM, TIA registers and CPU registers to 0
  CLEAN_START
Reset
	; seed the random number generator
	lda INTIM       ; unknown value
	sta Rand8       ; use as seed
	eor #$FF        ; both seed values cannot be 0, so flip the bits

	; set up srptie pos
	ldx #0

	; reset lives, map and level to 0
	stx CurrentMap

	jsr NextMap
	jsr NextLevel

	ldx #2
	stx Lives ; 2 lives

	jsr ResetPPositions

	jsr SetM0Pos

	ldx #1 ; only set intro state here
	stx GameState

StartOfFrame
	; start of new frame
	inc Framecount

	ldx RandMap
	inx
	cpx #MAPCOUNT+1
	bne MapCountRandNotReached
	ldx #0
MapCountRandNotReached
	stx RandMap

	; compare Framecount to 0
	ldx Framecount
	cpx #0
	bne FramesNotRolledOver
	dec M0RespawnTimer ; dec this if rolled over

	; compare to 0
	ldx M0RespawnTimer
	cpx #0
	bne FramesNotRolledOver
	; reset ball
	jsr SetM0Pos
FramesNotRolledOver

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

	lda #%00100000    ;
  sta NUSIZ0  ; set missile0 to be 2x

	; if the level is greater than 0x10 doulbe the bird
	ldx Level
	cpx #$10
	beq DoubleBird
	cpx #$FF
	beq TrippleBird
	jmp BirdDifficultyDone
DoubleBird
	lda #%00000001 ; 2 closely rendered copies
	sta NUSIZ1
	jmp BirdDifficultyDone
TrippleBird
	lda #%00000011 ; 3 closely rendered copies
	sta NUSIZ1
	jmp BirdDifficultyDone
BirdDifficultyDone
Sleep12 ; jsr here to sleep for 12 cycles
	rts

VerticalBlank
	jsr Random ; just call this to seed
	; game logic call
	jsr ProcessJoystick
	jsr GameProgress
	jsr PositionObjects

	ldx #1
	stx Temp+3 ; score colours
	jsr SetObjectColours

	jsr PrepScoreForDisplay
	ldx #0 ; channel 1
	jsr SoundHandle
	ldx #1 ; channel 2
	jsr SoundHandle
	rts

Picture
	; turn on display
	sta WSYNC ; Wait for SYNC (halts CPU until end of scanline)
	lda INTIM ; check vertical sync timer
	bne Picture
	sta VBLANK ; turn on the display

	; check for gamestate 2
	ldx GameState
	cpx #2 ; level clear
	bne GameStateNot2Picture
	; draw 197 lines
	ldx #192
GameStateLevelClearLoop
	dex
	sta WSYNC
	bne GameStateLevelClearLoop

	ldx Temp+1
	dex
	bne GameState2NotDone
	; set gamestate to 0 again
	ldx #0
	stx GameState
GameState2NotDone
	stx Temp+1
	rts
GameStateNot2Picture
	; draw score 5 lines
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

	; restore bg colour
	ldx #0
	stx Temp+3 ; gameplay colours
	jsr SetObjectColours

	sta WSYNC ; space between score and arena

	lda #1              ; 2  2
	sta CTRLPF          ; 3  5 - turn off SCORE mode and turn on REFLECT

	; load map counter into x
	ldx CurrentMap

	; now we load the map ptrs
	lda RoomTable,x ; store room1layout in MapPtr as a ptr
	sta MapPtr0
	lda RoomTable+1,x ;
	sta MapPtr0+1 ; store the rest in MapPtr+1

	ldx CurrentMap+1
	lda RoomTable+2,x ; store room1layout in MapPtr as a ptr
	sta MapPtr1
	lda RoomTable+3,x ;
	sta MapPtr1+1 ; store the rest in MapPtr+1

	ldx CurrentMap+2
	lda RoomTable+4,x ; store room1layout in MapPtr as a ptr
	sta MapPtr2
	lda RoomTable+5,x ;
	sta MapPtr2+1 ; store the rest in MapPtr+1

	; Do 192 scanlines of colour-changing (our picture)
	ldy #PFHEIGHT ; draw the screen for 192 lines
	ldx #0
	stx Temp ; store map counter in temp
pfLoop
	tya ; 2 29 - 2LK loop counter in A for testing
	and #%11 ; 2 31 - test for every 4th time through the loop,
	bne SkipMapCounter ; 2 33 (3 34) branch if not 4th time
	inc Temp ; 2 35 - if 4th time, increase Temp so new playfield data is used
SkipMapCounter

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

	; store current y in temp+1
	sty Temp+1
	ldy Temp ; load map counter
	; draw playfield
	lda (MapPtr0),y ; playfiled pattern test
	sta PF0
	lda (MapPtr1),y ; playfiled pattern test
	sta PF1
	lda (MapPtr2),y ; playfiled pattern test
	sta PF2

	; restore y
	ldy Temp+1

	; ball stuff
	ldx #1 ; d1=0 so ball will be off
	lda #M0HEIGHT-1 ; height of m0 gfx
	dcp M0Draw ; decrement and compare
	bcs DoEnableM0
	.byte $24
DoEnableM0
	inx ; d1=1 so ball will be on

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
	stx ENAM0 ; enable m0
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

	jsr CollisionDetection

	lda #1
overscanLoop
	sta WSYNC
	lda INTIM ; check timer
	bpl overscanLoop
	rts

ProcessJoystick
	; first we check the reset button
	lda SWCHB
	lsr
	bcs ResetNotPressed ; if reset is hit, literally reset
	jmp Start
ResetNotPressed
	lsr             ; D1 is now in C
	bcs SelectNotPressed
	ldx GameState
	cpx #1
	beq SelectPressedStartGame
	lda #1
	sta GameState ; pause game
	jmp SelectNotPressed
SelectPressedStartGame
	lda #0
	sta GameState ; game is now running
SelectNotPressed
	; then we check fire button, it will start/pause the game

	ldx GameState ; load gamestate to see what is happening
	cpx #0
	beq JoystickPlaying ; playing input only
	rts ; otherwise return now
JoystickPlaying
	; now we store old x and y
	ldx ObjectX
	stx PreviousX
	ldx ObjectY
	stx PreviousY

	ldx ObjectX+1
	stx PreviousX+1
	ldx ObjectY+1
	stx PreviousY+1

	; load Temp with 0 to enable collision
	ldx #0
	stx Temp
	; game logic here
	lda  SWCHA ; input registr
	asl  ; test bit 0, left joy - right input
	bcs Player1RightNotPressed ; this operation sets the carry for the fromer bit that fell off
	ldy #0 ; right presses
	ldx #0
	jsr MoveObject
Player1RightNotPressed
	asl ; test bit 1, left joy - left input
	bcs Player1LeftNotPressed
	ldy #0 ; left presses
	ldx #1
	jsr MoveObject
Player1LeftNotPressed
	asl ; test bit 1, left joy - down input
	bcs Player1DownNotPressed
	ldy #0
	ldx #2
	jsr MoveObject
Player1DownNotPressed
	asl ; test bit 2, left joy - up input
	bcs Player1UpNotPressed
	ldy #0
	ldx #3
	jsr MoveObject
Player1UpNotPressed

	; set Temp to 1 to disable collision for bird
	ldx #1
	stx Temp

	; check left difficulty switch
	bit SWCHB       ; state of Right Difficult in N (negative flag)
									; state of Left Difficult in V (overflow flag)
	bvc LeftIsBJoy

	jsr BirdAI
	rts      ; Left is A, return now TODO insert AI sub call here
LeftIsBJoy
	; left is b, player 2 can control the bird
	asl ; test bit, right joy - right input
	bcs Player2RightNotPressed
	ldy #1
	ldx #0
	jsr MoveObject
Player2RightNotPressed
	asl ; test bit 1, right joy - left input
	bcs Player2LeftNotPressed
	ldy #1
	ldx #1
	jsr MoveObject
Player2LeftNotPressed
	asl ; test bit 1, right joy - down input
	bcs Player2DownNotPressed
	ldy #1
	ldx #2
	jsr MoveObject
Player2DownNotPressed
	asl ; test bit 2, right joy - up input
	bcs Player2UpNotPressed
	ldy #1
	ldx #3
	jsr MoveObject
Player2UpNotPressed
	rts

; this sub handles the bird AI
BirdAI
	ldx #0
	cpx BirdAICounter
	bne MoveBirdAI ; jump to keep doing what we are doing

	bit SWCHB ; only do non-random pattern on difficulty b
	bmi RandomBirdAI ; means switch is A

	; ldx Level ; if level is smaller than 5 random moves
	; cpx #5

	; bmi RandomBirdAI ; if smaller than this jmp
	ldx ObjectX ; player x
	cpx ObjectX+1 ; bird x
	bmi MoveLeftStructuredBird

	ldx #0
	stx BirdLeftRightStatus
	jmp LeftRightBirdAIDone
MoveLeftStructuredBird
	ldx #1
	stx BirdLeftRightStatus

	jmp LeftRightBirdAIDone

RandomBirdAI
	; first we call Random to determine which direction bird moves
	jsr Random
	; if random is even move left, else right
	lda #1 ; bit mask
	and Rand8
	beq EvenLeftRightBirdAI; is even


OddLeftRightBirdAI
	; odd bird AI
	ldx #0
	stx BirdLeftRightStatus
	jmp LeftRightBirdAIDone
	; even bird AI
EvenLeftRightBirdAI
	ldx #1
	stx BirdLeftRightStatus
LeftRightBirdAIDone

	jsr Random
	; if random is even move up, else down
	lda #1 ; bit mask
	and Rand8
	beq EvenUpDownBirdAI; is even

OddUpDownBirdAI
	; odd
	ldx #0
	stx BirdUpDownStatus
	jmp UpDownBirdAIDone
 	; even
EvenUpDownBirdAI
	ldx #1
	stx BirdUpDownStatus
UpDownBirdAIDone
	;lda #20 ; bird ai will follow this pattern for 20 frames
	;clc
	;adc Rand8
	lda Rand8
	clc
	sbc Level ; bird pattern changes in Rand8 minus Level time
	sta BirdAICounter

MoveBirdAI
	dec BirdAICounter
	; now we check where to move bird
	ldx #1
	cpx BirdUpDownStatus
	beq MoveBirdUp

	; odd bird AI
	ldy #1
	ldx #2
	jsr MoveObject
	jmp UpDownBirdMoveDone
MoveBirdUp
	ldy #1
	ldx #3
	jsr MoveObject
UpDownBirdMoveDone

	ldx #1
	cpx BirdLeftRightStatus
	beq MoveBirdLeft
	; move right
	ldy #1
	ldx #0
	jsr MoveObject
	jmp leftRightBirdMoveDone
MoveBirdLeft
	ldy #1
	ldx #1
	jsr MoveObject
leftRightBirdMoveDone
	rts

GameProgress
	; first we check if required maps for next level have been reached
	ldx Level ; maps for level are always Level
	;inx ; maps for level are always Level+1
	cpx MapsCleared ; if it is the same next level
	beq NextLevelProg
	ldx Score
	cpx #0 ; if score is 0 advance to the next stage
	beq NextMapProg

	jmp ProgressDone
NextMapProg
	jsr NextMap
	jsr ResetPPositions
	jmp ProgressDone
NextLevelProg
	jsr NextLevel
ProgressDone
	rts

;====================
; This sub checks for collision based on inputs stored
; Expected inputs:
; y - object's address offset, p0, p1, m0, m1
; x - move left, right, up, or down
; set Temp memory address to 1 to ignore collision.
; every other value will NOT ignore collision
; Retruns: 0, 1 or 2 in x
; 0 = no collision
; 1 = wall collision
; 2 = bird collision
; 3 = missile collision
;====================
MoveObject
	cpx #0
	beq RightCollision
	cpx #1
	beq LeftCollision
	cpx #2
	beq UpCollision
	jmp DownCollision
RightCollision
	; right pressed code
	ldx ObjectX,y
	inx
	cpx #160
	bne SaveXRight ; save X if we're not at the edge
	ldx #0 ; warp to other edge
SaveXRight
	stx ObjectX,y
	ldx #1
	stx REFP0,y ; makes turtle image face right
	rts;jmp MoveDone
LeftCollision
	; left pressed code
	ldx ObjectX,y
	dex
	cpx #255 ; test for edge of screen
	bne SaveXLeft
	ldx #159 ; warp to toher side
SaveXLeft
	stx ObjectX,y
	ldx #0
	stx REFP0,y ; makes turtle image face left
	rts;jmp MoveDone
DownCollision
	; up pressed code
	ldx ObjectY,y
	inx
	cpx #PFHEIGHT+3 ; used to be $60 - works with $FF too because this is the edge of the screen
	bne SaveYUp
	ldx #0
SaveYUp
	stx ObjectY,y
	rts;jmp MoveDone
UpCollision
	; down pressed code
	ldx ObjectY,y
	dex
	cpx #$0
	bne SaveYDown
	ldx #PFHEIGHT
SaveYDown
	stx ObjectY,y

MoveDone
	rts

	;====================
	; This sub checks for collision based on inputs stored
	; Expected inputs:
	; y = object's address offset
	; Retruns: nothing
	;====================
RestorePos
	lda PreviousX,y
	sta ObjectX,y
	lda PreviousY,y
	sta ObjectY,y
	rts

	;====================
	; This sub checks for collision based on inputs stored
	; Expected inputs:
	; y - object's address offset, p0, p1, m0, m1
	; set Temp memory address to 1 to ignore collision.
	; set Temp to 2 to not restore position
	; every other value will NOT ignore collision
	; Retruns: 0 or 1 in Temp and Temp+1
	; 0 = no collision
	; 1 = collision
	; returns Temp for lower bit and Temp+1 for higher bit
	; those mean different things depending on the check performed
	;====================
CollisionDetection
	; First we check collision for p0 and pf
	bit CXP0FB ; N = player0/playfield, V=player0/ball
	bpl NoP0PFCollision ; if N is off, then player did not collide with playfield
	ldy #0 ; 0th object is player0
	jsr RestorePos
NoP0PFCollision
	; now we check collision between p1 and pf only if difficulty right switch is b
	bit SWCHB
	bpl NoP1PFCollision ; means switch is off
	; if it is on do collision
	bit CXP1FB
	bpl NoP1PFCollision
	ldy #1 ; p1
	jsr RestorePos
	ldx #0
	stx BirdAICounter ; make bird change position
NoP1PFCollision

	; now we check collision between p0 and p1
	bit CXPPMM
	bpl NoP0P1Collision
	dec Lives ; kill p0
	lda #0 ; if lives is 0 - reset the game
	cmp Lives
	bne NoReset
	jmp Reset
NoReset
	jsr ResetPPositions
	jsr SetM0Pos

	ldx #0 ; first song
	ldy #BIRDHITPLAYERTRACKSIZE
	jsr PlaySong
NoP0P1Collision ; p0 and p1 did not collide!

	; now we dio p0 m0 collision. m0 must be collected by turtle to advance
	; each time collision happens m0 will get a new position
	bit CXM0P
	bvc NoP0M0Collision

	ldx Score
	cpx #0
	beq NoP0M0Collision ; prevent underflow!
	; dec score. if screen is left and score is 0 continue
	dex
	stx Score
	jsr SetM0Pos ; new position for m0

	ldx #2 ; second song
	ldy #FOODCOLLECTEDTRACKSIZE
	jsr PlaySong
NoP0M0Collision
	; now we check if m0 is in a wall
	bit CXM0FB
	bpl NoM0PFCollision ; if it is reloacte
	jsr SetM0Pos
NoM0PFCollision
CollisionDone
	lda #1
	sta CXCLR ; clear collision
	rts

; Plays the Intro noise
SoundHandle
	ldy SoundEnabled,x
	cpy #0 ; if it is 0, clear song and return
	beq ClearSongSet
	jsr Sound ; else we call sound
	rts
ClearSongSet
	jsr ClearSong
	rts

Sound
	ldy SoundEnabled,x
	cpx #0
	bne LoadTrackPtr2
	lda (SoundTrackPtr),y
	sta AUDF0,x


	lda (SoundControl),y ; get the combined Control and Volume value
	jmp TrackPtrLoaded
LoadTrackPtr2
	lda (SoundTrackPtr2),y
	sta AUDF0,x
	lda (SoundControl2),y
TrackPtrLoaded

	sta AUDV0,x ; update the Volume register
	lsr
	lsr
	lsr
	lsr ; the lower nibble is control
	sta AUDC0,x

	; dec every 2nd frame
	;lda Framecount
	;and SoundSpeed
	;beq DoNotDecSound
	dec SoundEnabled,x
DoNotDecSound
	rts

ClearSong
	; song done, now we quit
	lda #0
	sta AUDC0,x
	sta AUDF0,x
	sta AUDV0,x
	rts

; subroutine
; inputs: x = offset in track and control table
; y = track length
PlaySong
	lda #SoundTrackTable,x
	sta SoundTrackPtr
	lda #SoundTrackTable+1,x
	sta SoundTrackPtr+1

	sty SoundEnabled

	lda #SoundControlTable,x
	sta SoundControl

	lda #SoundControlTable+1,x
	sta SoundControl+1

	rts


SetM0Pos
	ldx 2
	jsr RandomLocation
	lda #M0RESPAWNT ; load ball respawn time
	; dec level from that
	clc
	sbc Level
	sta M0RespawnTimer
	rts

	;===============================================================================
	; RandomLocation
	; --------------
	; call with X to set to the object to randomly position:
	;   1 - player1
	;   2 - missile0
	;   3 - missile1
	;   4 - ball
	;
	; X position
	; ----------
	; There are 160 pixels across the screen.  There's also a border that takes up
	; 4 pixels on each side, plus the player objects span 8 pixels.  That gives us
	; a range of 160 - 4*2 - 8 = 144 possible positions to place an object.  Due to
	; due to the Arena border we need to shift that 4 to the right so the X position
	; can be anything from 4-148.
	;
	; Y position
	; ----------
	; Y position needs to be between 25-169
	;===============================================================================
RandomLocation:
	jsr Random      ; get a random value between 0-255
	and #127        ; limit range to 0-127
	sta Temp        ; save it
	jsr Random      ; get a random value between 0-255
	and #15         ; limit range to 0-15
	clc             ; must clear carry for add
	adc Temp        ; add in random # from 0-127 for range of 0-142
	adc #5          ; add 5 for range of 5-147
	sta ObjectX,x   ; save the random X position

	jsr Random      ; get a random value between 0-255
	and #127        ; limit range to 0-127
	sta Temp        ; save it
	jsr Random      ; get a random value between 0-255
	and #15         ; limit range to 0-15
	clc             ; must clear carry for add
	adc Temp        ; add in random # from 0-127 for range of 0-142
	adc #26         ; add 26 for range of 26-168
	sta ObjectY,x   ; save the random Y position
	rts

ResetPPositions
	ldx #P0STARTX
	stx ObjectX
	ldy #P0STARTY
	sty ObjectY

	ldx P1STARTX
	stx ObjectX+1
	ldx P1STARTY
	stx ObjectY+1
	rts

NextLevel
	inc Level
	inc Lives
	lda #3
	clc
	adc Level
	; score is 3 + level
	sta Score
	ldx #0
	stx MapsCleared

	ldx #2 ; store 2 in gamestate to play level clear animation and play the tune
	stx GameState
	ldx #LEVELCLEARTRACKSIZE*2
	stx Temp+1 ; used for frame counter for blank screen

	ldx #4 ; third song
	ldy #LEVELCLEARTRACKSIZE
	jsr PlaySong
	rts

NextMap
	inc Lives
	inc MapsCleared
	lda #3
	adc Level
	; score is 3 + level
	sta Score

	; now we roll for next map

	; this is the new code for generating maps from fragments
	;jsr Random
	;lda Rand8
	;and #ROOMTABLESIZE ; only allow MAPCOUNT for roll
	;sta CurrentMap
	;lda Rand8
	;and #ROOMTABLESIZE ; only allow MAPCOUNT for roll
	;sta CurrentMap+1
	;lda Rand8
	;and #ROOMTABLESIZE ; only allow MAPCOUNT for roll
	;sta CurrentMap+2

	; this is the old code to pick a static map
	; jsr Random
	; lda Rand8
	; and #MAPCOUNT-1 ; only allow MAPCOUNT for roll
	; tay
	ldy RandMap
	cpy #0 ; 0 does not require an offset
	beq NextMapDone
	;dey
	lda #OFFSETPERMAP
	sta Temp
	lda #0
	; now add 6 for each number rolled
NextMapLoop
	clc
	adc Temp
	dey
	bne NextMapLoop
	sta CurrentMap
	sta CurrentMap+1
	sta CurrentMap+2
NextMapDone
	rts

; if temp+3 is loaded with 1 then prepare for score colours
SetObjectColours
	; check for gamestate 2
	ldx GameState
	cpx #2 ; level clear
	bne GameStateNot2Col

	lda #$86 ; blue for background
	sta COLUBK
	rts ; and return
GameStateNot2Col
	ldy #3 ; we're going to set 4 colours
	; ldy #3 ;
	lda SWCHB ; read the state of the console switches
	and #%00001000  ; test state of D3, the TV Type switch
	bne SOCloop ; if D3=1 then use colour
	ldy #7 ; else b&w entries in table
SOCloop
	ldx Temp+3
	cpx #1
	beq PickScoreCol
	lda Colours,y ; get the colour or b&w value
	jmp PFColPicked
PickScoreCol
	lda ScoreColours,y
PFColPicked
	sta Temp ; store a for now
	ldx GameState ; load gamestate to see what is happening
	cpx #0
	beq ColoursNotPaused
	cpx #2
	beq ColoursNotPaused
	lda Framecount
	and #%11111 ; test for every 4th frame
	bne DoNotIncrementCCycle
	inc ColourCycle
DoNotIncrementCCycle
	; if game is paused add colour variations
	clc
	lda Temp
	adc ColourCycle
	jmp PauseScreenColoursDone
ColoursNotPaused
	lda Temp ; restore a now
PauseScreenColoursDone

	sta COLUP0,y ; and set it
	dey ; decrease y

	bpl SOCloop ; branch if positive
	rts ; return

PrepScoreForDisplay
	; for testing purposes, change the values in Timer and Score
	; inc Timer ; inc timer by 1
	; bne PSFDskip ; branch if not 0
	; inc Score ; inc score by 1 if Timer just rolled to 0
	ldx Lives
	stx Timer
PSFDskip
	ldx #2 ; use x as the loop counter for PSFDloop
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
	ldx #2 ; position objects 0-1: player0 and player1 and m0
POloop
	lda ObjectX,x       ; get the object's X position
	jsr PosObject       ; set coarse X position and fine-tune amount
	dex                 ; DEcrement X
	bpl POloop          ; Branch PLus so we position all objects
	sta WSYNC           ; wait for end of scanline
	sta HMOVE           ; use fine-tune values to set final X positions

	; every other frame load different animation
	ldx AnimationTimer
	inc AnimationTimer
	cpx #10 ; every 5th or more frame draw 2nd frame
	bmi TurtleFrame1
	jmp TurtleFrame2 ; TODO this can be made much better
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
	jmp BirdRender

TurtleFrame2
	; TurtleDraw = PFHEIGHT + TURTLEHEIGHT - Y position
	lda #(PFHEIGHT + TURTLEHEIGHT2)
	sec
	sbc ObjectY
	sta TurtleDraw

	; TurtlePtr = PFHEIGHT + TURTLEHEIGHT - 1 - Y position
	lda #<(TurtleSprite2 + TURTLEHEIGHT2 - 1) ; because sprite is upside down
	sec
	sbc ObjectY
	sta TurtlePtr
	lda #>(TurtleSprite2 + TURTLEHEIGHT2 - 1)
	sbc #0
	sta TurtlePtr+1

	ldx AnimationTimer
	cpx #20 ; compare to 10 if 10 reset to 0
	bne BirdRender
	lda #0
	sta AnimationTimer

BirdRender
	; every other frame load different animation
	ldx AnimationTimer+1
	inc AnimationTimer+1
	cpx #10 ; every 5th or more frame draw 2nd frame
	bmi BirdFrame1
	jmp BirdFrame2 ; TODO this can be made much better

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
	jmp BallRender
BirdFrame2
	; BirdDraw = PFHEIGHT + BIRDHEIGHT - Y position
	lda #(PFHEIGHT + BIRDHEIGHT2)
	sec
	sbc ObjectY+1
	sta BirdDraw

	; BirdPtr = TurtleSprite + TURTLEHEIGHT - 1 - Y position
	lda #<(BirdSprite2 + BIRDHEIGHT2 - 1)
	sec
	sbc ObjectY+1
	sta BirdPtr
	lda #>(BirdSprite2 + BIRDHEIGHT2 - 1)
	sbc #0
	sta BirdPtr+1

	ldx AnimationTimer+1
	cpx #20 ; compare to 10 if 10 reset to 0
	bne BallRender
	lda #0
	sta AnimationTimer+1

BallRender
	ldx #1
	lda ObjectY+2
	lsr
	sta Temp
	bcs NoDelayBL
	stx VDELBL
NoDelayBL
	; prep m0 y position
	lda #(PFHEIGHT + M0HEIGHT)
	sec
	sbc Temp
	sta M0Draw
RenderDone
	; use Difficulty Switches to test how Vertical Delay works
	;ldx #0
	;stx VDELP0      ; turn off VDEL for player0
	;stx VDELP1      ; turn off VDEL for player1
	;inx
	;bit SWCHB       ; state of Right Difficult in N (negative flag)
									; state of Left Difficult in V (overflow flag)
	;bvc LeftIsB
	;stx VDELP0      ; Left is A, turn on VDEL for player0
;LeftIsB
	;bpl RightIsB
	;stx VDELP1      ; Right is A, turn on VDEL for player1
;RightIsB
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

;===============================================================================
; This routine returns a random number based on the last value of Rand8
; Expected inputs:
; none
; Returns: A 8-bit random number in Rand8
;===============================================================================
Random
	lda Rand8
	lsr
	bcc noeor
	eor #$B4
noeor
	sta Rand8
	rts

	; Free memory check
	ECHO ([$FFFA-*]d), "bytes free before end data segment ($FFFA)"

#if SYSTEM = NTSC
Colours:
	.byte $C6   ; green      - goes into COLUP0, color for player1 and missile0
	.byte $86   ; blue       - goes into COLUP1, color for player0 and missile1
	.byte $46   ; red        - goes into COLUPF, color for playfield and ball
	.byte $EE   ; yellowish      - goes into COLUBK, color for background
	.byte $0E   ; white      - goes into COLUP0, B&W for player0 and missile0
	.byte $06   ; dark grey  - goes into COLUP1, B&W for player1 and missile1
	.byte $0A   ; light grey - goes into COLUPF, B&W for playfield and ball
	.byte $00   ; black      - goes into COLUBK, B&W for background
ScoreColours:
	.byte $29   ; green      - goes into COLUP0, color for player1 and missile0
	.byte $9C   ; blue       - goes into COLUP1, color for player0 and missile1
	.byte $46   ; red        - goes into COLUPF, color for playfield and ball
	.byte $00   ; black      - goes into COLUBK, color for background
	.byte $0E   ; white      - goes into COLUP0, B&W for player0 and missile0
	.byte $06   ; dark grey  - goes into COLUP1, B&W for player1 and missile1
	.byte $0A   ; light grey - goes into COLUPF, B&W for playfield and ball
	.byte $00   ; black      - goes into COLUBK, B&W for background
#endif

#if SYSTEM = PAL
Colours:
	.byte $3A   ; green      - goes into COLUP0, color for player1 and missile0
	.byte $B4   ; blue       - goes into COLUP1, color for player0 and missile1
	.byte $66   ; red        - goes into COLUPF, color for playfield and ball
	.byte $00   ; black      - goes into COLUBK, color for background
	.byte $0E   ; white      - goes into COLUP0, B&W for player0 and missile0
	.byte $14   ; dark grey  - goes into COLUP1, B&W for player1 and missile1
	.byte $1A   ; light grey - goes into COLUPF, B&W for playfield and ball
	.byte $00   ; black      - goes into COLUBK, B&W for background
ScoreColours:
	.byte $C6   ; green      - goes into COLUP0, color for player1 and missile0
	.byte $86   ; blue       - goes into COLUP1, color for player0 and missile1
	.byte $46   ; red        - goes into COLUPF, color for playfield and ball
	.byte $00   ; black      - goes into COLUBK, color for background
	.byte $0E   ; white      - goes into COLUP0, B&W for player0 and missile0
	.byte $06   ; dark grey  - goes into COLUP1, B&W for player1 and missile1
	.byte $0A   ; light grey - goes into COLUPF, B&W for playfield and ball
	.byte $00   ; black      - goes into COLUBK, B&W for background
#endif

#if SYSTEM = SECAM
Colours:
	.byte $3A   ; green      - goes into COLUP0, color for player1 and missile0
	.byte $B4   ; blue       - goes into COLUP1, color for player0 and missile1
	.byte $66   ; red        - goes into COLUPF, color for playfield and ball
	.byte $00   ; black      - goes into COLUBK, color for background
	.byte $0E   ; white      - goes into COLUP0, B&W for player0 and missile0
	.byte $14   ; dark grey  - goes into COLUP1, B&W for player1 and missile1
	.byte $1A   ; light grey - goes into COLUPF, B&W for playfield and ball
	.byte $00   ; black      - goes into COLUBK, B&W for background
ScoreColours:
	.byte $C6   ; green      - goes into COLUP0, color for player1 and missile0
	.byte $86   ; blue       - goes into COLUP1, color for player0 and missile1
	.byte $46   ; red        - goes into COLUPF, color for playfield and ball
	.byte $00   ; black      - goes into COLUBK, color for background
	.byte $0E   ; white      - goes into COLUP0, B&W for player0 and missile0
	.byte $06   ; dark grey  - goes into COLUP1, B&W for player1 and missile1
	.byte $0A   ; light grey - goes into COLUPF, B&W for playfield and ball
	.byte $00   ; black      - goes into COLUBK, B&W for background
#endif

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
	.byte %01111110
	.byte %00111100
	.byte %01111110
	.byte %01011010
	.byte %01000010
TURTLEHEIGHT2 = * - TurtleSprite2

;TurtleDeadSprite:
;	.byte %10000001
;	.byte %01000010
;	.byte %00100100
;	.byte %00011000
;	.byte %00011000
;	.byte %00100100
;	.byte %01000010
;	.byte %10000001
;TURTLEHDEADEIGHT = * - TurtleDeadSprite

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

BirdSprite2:
	.byte %00000000
	.byte %00011000
	.byte %00011000
	.byte %00100100
	.byte %01011010
	.byte %10011001
	.byte %00011000
	.byte %00100100
BIRDHEIGHT2 = * - BirdSprite2

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
; Reminder that pf0 only uses 4 bits
Room0LayoutPF0:
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %11110000
	.byte %00010000
	.byte %00000000
	.byte %00000000
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %00010000
	.byte %00000000
	.byte %00000000
	.byte %00010000
	.byte %11110000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %11110000
Room0LayoutPF1:
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00011000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00011000
	.byte %00011000
	.byte %00111100
	.byte %01111110
	.byte %01111110
	.byte %01111110
	.byte %00111100
	.byte %00011000
	.byte %00011000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00011000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00111100
Room0LayoutPF2:
	.byte %00000000
	.byte %10000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00011100
	.byte %00000100
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000100
	.byte %00011100
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %10000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000

Room1LayoutPF0
	.byte %00001111
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00111001
	.byte %00001001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %10001001
	.byte %10001001
	.byte %10001001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00001001
	.byte %00111001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00001111
Room1LayoutPF1
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00111110
	.byte %00000010
	.byte %00000010
	.byte %00000010
	.byte %00000010
	.byte %11111110
	.byte %11111110
	.byte %11111110
	.byte %00000010
	.byte %00000010
	.byte %00000010
	.byte %00000010
	.byte %00111110
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
Room1LayoutPF2
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00111110
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00100000
	.byte %00111110
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000

Room2LayoutPF0:
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
Room2LayoutPF1:
	.byte %00011000
	.byte %00011000
	.byte %00011000
	.byte %00011000
	.byte %00011000
	.byte %00111100
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00111100
	.byte %00011000
	.byte %00011000
	.byte %00011000
	.byte %00011000
	.byte %00011000
	.byte %00111100
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00111100
	.byte %00011000
	.byte %00011000
	.byte %00011000
	.byte %00011000
Room2LayoutPF2:
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %11111110
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %11000000
	.byte %00111110
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %01011100
	.byte %00000000
	.byte %00000000
	.byte %01000000
	.byte %01111001
	.byte %00000001
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000

Room3LayoutPF0:
	.byte %00000000
	.byte %00000000
	.byte %01000000
	.byte %01000000
	.byte %01000000
	.byte %01000000
	.byte %01000000
	.byte %01000000
	.byte %01000000
	.byte %01000000
	.byte %11000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %10000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %10000000
	.byte %00000000
	.byte %00000000
Room3LayoutPF1:
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %01111000
	.byte %00001000
	.byte %00001000
	.byte %00001000
	.byte %11111000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %11111111
	.byte %00000000
	.byte %00000000
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %11111111
	.byte %00000000
	.byte %00000000
Room3LayoutPF2:
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %11111110
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %11000000
	.byte %00111110
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %01111111
	.byte %01000001
	.byte %01000001
	.byte %01000001
	.byte %01111001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000001
	.byte %00000000
	.byte %00000000

; Table holding all the room start addresses next to each other
; might be able to store this in 3 different tables and not have the counter
; be a multiple of 6
; this is not really an issue at this time because we will be able to fit
; enough maps anyway
RoomTable:
	.word Room0LayoutPF0
	.word Room0LayoutPF1
	.word Room0LayoutPF2

	.word Room1LayoutPF0
	.word Room1LayoutPF1
	.word Room1LayoutPF2

	.word Room2LayoutPF0
	.word Room2LayoutPF1
	.word Room2LayoutPF2

	.word Room3LayoutPF0
	.word Room3LayoutPF1
	.word Room3LayoutPF2

	; mix and match room
	.word Room2LayoutPF0
	.word Room3LayoutPF1
	.word Room1LayoutPF2

	.word Room0LayoutPF0
	.word Room1LayoutPF1
	.word Room2LayoutPF2

	.word Room3LayoutPF0
	.word Room1LayoutPF2
	.word Room0LayoutPF2

	.word Room1LayoutPF0
	.word Room3LayoutPF2
	.word Room0LayoutPF2

	.word Room0LayoutPF0
	.word Room1LayoutPF2
	.word Room0LayoutPF2

	.word Room0LayoutPF0
	.word Room1LayoutPF2
	.word Room0LayoutPF2

	.word Room2LayoutPF0
	.word Room1LayoutPF1
	.word Room3LayoutPF2

	.word Room1LayoutPF0
	.word Room3LayoutPF2
	.word Room3LayoutPF2
ROOMTABLESIZE = * - RoomTable

; Sound tables
; frequencies in order
BirdHitPlayerTrack
	.byte 0, 31, 29, 27, 25, 23, 21, 19, 17, 15, 13, 11
BIRDHITPLAYERTRACKSIZE = * - BirdHitPlayerTrack-1

 ; the control tables hold the control instrumnet in the first number and the volume in the 2nd
BirdHitPlayerControl
	.byte 0, $8F, $8F, $8F, $8F, $8F, $8F, $8F, $8F, $8F, $8F, $8F

FoodCollectedTrack
	.byte 0, 26, 25, 24, 25, 26
FOODCOLLECTEDTRACKSIZE = * - FoodCollectedTrack-1

FoodCollectedControl
	.byte 0, $1B, $1C, $4D, $4E, $4F

LevelClearTrack
	.byte 0, 21, 21, 22, 22, 23, 23, 20, 20, 21, 21, 22, 22, 19, 19, 20, 20, 21, 21
LEVELCLEARTRACKSIZE = * - LevelClearTrack-1

LevelClearControl
	.byte 0, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F
	.byte $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F

; table holding all the needed addresses
SoundTrackTable
	.word BirdHitPlayerTrack
	.word FoodCollectedTrack
	.word LevelClearTrack

SoundControlTable
	.word BirdHitPlayerControl
	.word FoodCollectedControl
	.word LevelClearControl

	; Free memory check
	ECHO ([$FFFA-*]d), "bytes free before end of cart ($FFFA)"

	;------------------------------------------------------------------------------

	ORG $FFFA ; set address to 6507 Interrupt Vectors

	;===============================================================================
	; Define End of Cartridge
	;===============================================================================
InterruptVectors
	.word Start          ; NMI
	.word Start          ; RESET
	.word Start          ; IRQ
END
