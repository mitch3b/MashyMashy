  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

;MITCH
;  .include "TitleScreen.asm"

; -----------------------------------
; Standard NES registers

PPU_CTRL_REG1         = $2000
PPU_CTRL_REG2         = $2001
PPU_STATUS            = $2002
PPU_SPR_ADDR          = $2003
PPU_SPR_DATA          = $2004
PPU_SCROLL_REG        = $2005
PPU_ADDRESS           = $2006
PPU_DATA              = $2007

SND_REGISTER          = $4000
SND_SQUARE1_REG       = $4000
SND_SQUARE2_REG       = $4004
SND_TRIANGLE_REG      = $4008
SND_NOISE_REG         = $400c
SND_DELTA_REG         = $4010
SND_MASTERCTRL_REG    = $4015

SPR_DMA               = $4014
CONTROLLER_PORT           = $4016
CONTROLLER_PORT1          = $4016
CONTROLLER_PORT2          = $4017

DISPLAY_NUMBERS_Y = 2
DISPLAY_P1_BP_HUNDREDS_TILE = $0205
DISPLAY_P1_BP_TENS_TILE = $0209
DISPLAY_P1_BP_ONES_TILE = $020D
DIPLAY_GT_TENS_TILES = $0211
DIPLAY_GT_ONES_TILES = $0215
DIPLAY_GT_TENTHS_TILES = $021D
DISPLAY_P2_BP_HUNDREDS_TILE = $0221
DISPLAY_P2_BP_TENS_TILE = $0225
DISPLAY_P2_BP_ONES_TILE = $0229

SCREEN_WIDTH_TILES = 32
SCREEN_HEIGHT_TILES = 30;
; -----------------------------------

  .rsset  $0000   ; start the reserve counter at memory address $0000
game_state  .rs 1     ; reserve one byte of space to track the current state
prev_game_state .rs 1 ; to see if state has changed. could hide this in game state
GAME_TITLE = 1
GAME_MENU = 2
GAME_PLAY = 3
GAME_OVER = 4

num_players .rs 1 ;

; What bit each button is stored in a controller byte
BUTTON_A      = %10000000
BUTTON_B      = %01000000
BUTTON_SELECT = %00100000
BUTTON_START  = %00010000
BUTTON_LEFT   = %00001000
BUTTON_RIGHT  = %00000100
BUTTON_UP     = %00000010
BUTTON_DOWN   = %00000001

p1_buttons   .rs 1  ; player 1 gamepad buttons, one bit per button
p2_buttons   .rs 1  ; player 2 gamepad buttons, one bit per button
p1_prev_buttons .rs 1 ; to track what buttons changed
p2_prev_buttons .rs 1 ; to track what buttons changed
p1_buttons_new_press .rs 1;
p2_buttons_new_press .rs 1;
start_pressed .rs 1 ; TODO this should really not take a full byte

frame_counter .rs 1;
p1_bp_counter_ones .rs 1;
p1_bp_counter_tens .rs 1;
p1_bp_counter_hundreds .rs 1;
p2_bp_counter_ones .rs 1;
p2_bp_counter_tens .rs 1;
p2_bp_counter_hundreds .rs 1;

game_over_time_s_ones .rs 1
game_over_time_s_tens .rs 1

FRAMES_PER_TENTH_SEC = 6 ; NTSC is 60 fps
less_than_tenth_sec_counter .rs 1

; Game seconds counter
game_timer_tenths .rs 1
game_timer_ones .rs 1
game_timer_tens .rs 1

p1_mash_button .rs 1;
p2_mash_button .rs 1;
new_frame .rs 1;

;;;;;;;;;;;;;;;

  .bank 0
  .org $C000
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX PPU_CTRL_REG1    ; disable NMI
  STX PPU_CTRL_REG2    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT PPU_STATUS
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
  INX
  BNE clrmem

vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT PPU_STATUS
  BPL vblankwait2

;MITCH
InitState:
  LDA #GAME_MENU
  STA game_state
  LDA #GAME_TITLE ; want states to disagree so that it'll load the first time
  STA prev_game_state

  LDA #$02
  STA num_players

  LDA #BUTTON_B
  STA p1_mash_button
  LDA #BUTTON_A
  STA p2_mash_button

; TODO make this configurable
  LDA #$05
  STA game_over_time_s_ones
  LDA #$01
  STA game_over_time_s_tens

LoadPalettes:
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$3F
  STA PPU_ADDRESS       ; write the high byte of $3F00 address
  LDA #$00
  STA PPU_ADDRESS       ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA PPU_DATA          ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down


LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0204, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$1C              ; Compare X to hex $1C, decimal 28 -> 7 chars, 4 bytes each
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

  LDA num_players
  CMP #$02
  BNE SkipP2
LoadP2Sprites:
  LDX #$00              ; start at 0
LoadP2SpritesLoop:
  LDA p2_sprites, x        ; load data from address (sprites +  x)
  STA $0220, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$18              ; Compare X to hex $20, decimal 32
  BNE LoadP2SpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

SkipP2:
LoadP1Label:
  LDX #$00
LoadP1LabelLoop:
  LDA p1_label, x
  STA $0238, x
  INX
  CPX #$0C
  BNE LoadP1LabelLoop

  LDA #%10001000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA PPU_CTRL_REG1

  LDA #%00010000   ; enable sprites, enable background, no clipping on left side
  STA PPU_CTRL_REG2

Forever:
  LDA new_frame
  BEQ FrameProcessed
  LDA #00
  STA new_frame ; reset new frame
  LDX game_state
  CPX #GAME_PLAY
  BNE FrameProcessed ; if games not in play, then jump to end
  ;TODO if counting down, keep doing it, else continue below
  JSR CalcGameTime
  JSR CalcButtonPresses
FrameProcessed:
  JMP Forever     ;jump back to Forever, infinite loop

NMI:
  LDA #$00
  STA PPU_SPR_ADDR       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

  LDX frame_counter; ;TODO this should be more than one byte
  INX

  JSR ReadController1
  JSR ReadController2

  LDA #01
  STA new_frame ; Tell forever loop that theres a new set of input to process

; TODO think it'd be better to just load it once and store result in A
GameLogic
  LDX game_state
  CPX #GAME_MENU
  BNE GameLogicPlay
  ;; we are in menu state so check if start was pressed to change state
  LDA p1_buttons
  AND #BUTTON_START
  BEQ EndGameLogic
  ;;; start was pressed
  LDA #GAME_PLAY
  STA game_state
  JMP EndGameLogic
GameLogicPlay:
  LDX game_state
  CPX #GAME_PLAY
  BNE EndGameLogic
  LDX game_timer_ones
  CPX game_over_time_s_ones
  BNE EndGameLogic
  LDX game_over_time_s_tens
  CPX game_timer_tens
  BNE EndGameLogic
  ;;;; Just hit the game over time so call the game over
  LDA #GAME_OVER
  STA game_state
EndGameLogic:

DrawFrameCount:
  LDA game_timer_tenths
  STA DIPLAY_GT_TENTHS_TILES
  LDA game_timer_ones
  STA DIPLAY_GT_ONES_TILES
  LDA game_timer_tens
  STA DIPLAY_GT_TENS_TILES
DrawButtonPresses:
  LDA p1_bp_counter_ones
  STA DISPLAY_P1_BP_ONES_TILE
  LDA p1_bp_counter_tens
  STA DISPLAY_P1_BP_TENS_TILE
  LDA p1_bp_counter_hundreds
  STA DISPLAY_P1_BP_HUNDREDS_TILE
  LDA p2_bp_counter_ones
  STA DISPLAY_P2_BP_ONES_TILE
  LDA p2_bp_counter_tens
  STA DISPLAY_P2_BP_TENS_TILE
  LDA p2_bp_counter_hundreds
  STA DISPLAY_P2_BP_HUNDREDS_TILE

  RTI             ; return from interrupt

CalcButtonPresses:
  LDA p1_buttons_new_press
  AND p1_mash_button
  BEQ P1DoneBPCalc ; branch if button not down
  LDX p1_bp_counter_ones ; We have a new press
  INX
  STX p1_bp_counter_ones
  CPX #$0A
  BNE P1DoneBPCalc ; if we went over 9
  LDA #00
  STA p1_bp_counter_ones
  LDX p1_bp_counter_tens
  INX ; TODO i think there might be a way to do this in place
  STX p1_bp_counter_tens
  CPX #$0A
  BNE P1DoneBPCalc ; if we went over 99
  LDA #00
  STA p1_bp_counter_tens
  LDX p1_bp_counter_hundreds
  INX
  STX p1_bp_counter_hundreds
P1DoneBPCalc:
  LDA p2_buttons_new_press
  AND p2_mash_button
  BEQ P2DoneBPCalc ; branch if button not down
  LDX p2_bp_counter_ones ; We have a new press
  INX
  STX p2_bp_counter_ones
  CPX #$0A
  BNE P2DoneBPCalc ; if we went over 9
  LDA #00
  STA p2_bp_counter_ones
  LDX p2_bp_counter_tens
  INX ; TODO i think there might be a way to do this in place
  STX p2_bp_counter_tens
  CPX #$0A
  BNE P2DoneBPCalc ; if we went over 99
  LDA #00
  STA p2_bp_counter_tens
  LDX p2_bp_counter_hundreds
  INX
  STX p2_bp_counter_hundreds
P2DoneBPCalc:
  RTS

CalcGameTime:
  LDX less_than_tenth_sec_counter
  INX
  STX less_than_tenth_sec_counter
  CPX #FRAMES_PER_TENTH_SEC
  BNE DoneGameTimeCalc
  LDA #$00
  STA less_than_tenth_sec_counter
  LDX game_timer_tenths
  INX
  STX game_timer_tenths
  CPX #$0A
  BNE DoneGameTimeCalc ; if we went over 9
  LDA #00
  STA game_timer_tenths
  LDX game_timer_ones
  INX ; TODO i think there might be a way to do this in place
  STX game_timer_ones
  CPX #$0A
  BNE DoneGameTimeCalc ; if we went over 99
  LDA #00
  STA game_timer_ones
  LDX game_timer_tens
  INX
  STX game_timer_tens
DoneGameTimeCalc:
  RTS

ReadController1:
  LDA p1_buttons
  STA p1_prev_buttons ; backup the previous buttons
  LDA #$01
  STA CONTROLLER_PORT1
  LDA #$00
  STA CONTROLLER_PORT1
  LDX #$08
ReadController1Loop:
  LDA CONTROLLER_PORT1
  LSR A              ; bit0 -> Carry
  ROL p1_buttons     ; bit0 <- Carry
  DEX
  BNE ReadController1Loop
  ; store what was newly pressed (not working)
  LDA p1_buttons
  EOR p1_prev_buttons
  AND p1_buttons
  STA p1_buttons_new_press
  RTS

ReadController2:
  LDA p2_buttons
  STA p2_prev_buttons ; backup the previous buttons
  LDA #$01
  STA CONTROLLER_PORT1
  LDA #$00
  STA CONTROLLER_PORT1
  LDX #$08
ReadController2Loop:
  LDA CONTROLLER_PORT2
  LSR A              ; bit0 -> Carry
  ROL p2_buttons     ; bit0 <- Carry
  DEX
  BNE ReadController2Loop
  ; store what was newly pressed (not working)
  LDA p2_buttons
  EOR p2_prev_buttons
  AND p2_buttons
  STA p2_buttons_new_press
  RTS

; ###############################
; Background/tile loading
; ###############################
  .bank 1
  .org $E000
palette:
  .db $0F,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F
  .db $0F,$1C,$15,$14,$31,$02,$38,$3C,$0F,$1C,$15,$14,$31,$02,$38,$3C

press_b_to_start:
  .db $19,$1B

sprites:
     ;vert tile attr horiz
  .db $80, $00, $00, $80   ;hundreds bp count
  .db $80, $00, $00, $88   ;tens bp count
  .db $80, $00, $00, $90   ;ones bp count
  .db $90, $00, $00, $80   ;p1 tens game timer
  .db $90, $00, $00, $88   ;p1 ones game timer
  .db $90, $AF, $00, $90   ;p1 decimal
  .db $90, $00, $00, $98   ;p1 tenths game timer

p2_sprites:
  .db $A0, $00, $00, $80   ;p2 hundreds game timer
  .db $A0, $00, $00, $88   ;p2 tens game timer
  .db $A0, $00, $00, $90   ;p2 ones game timer
  .db $A0, $19, $00, $60   ; 'p' TODO these should go in the background
  .db $A0, $02, $00, $68   ; '2'
  .db $A0, $28, $00, $70   ; '-'

p1_label:
  .db $80, $19, $00, $60   ; 'p' TODO these should go in the background
  .db $80, $01, $00, $68   ; '1'
  .db $80, $28, $00, $70   ; '-'

press_start:
  .db $19, $1B, $0E, $1C, $1C, $24, $1C, $1D, $0A, $1B, $1D

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial


;;;;;;;;;;;;;;


  .bank 2
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1
