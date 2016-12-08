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
DISPLAY_BP_HUNDREDS_TILE = $0205
DISPLAY_BP_TENS_TILE = $0209
DISPLAY_BP_ONES_TILE = $020D
DIPLAY_GFR_HUNDREDS_TILES = $0211
DIPLAY_GFR_TENS_TILES = $0215
DIPLAY_GFR_ONES_TILES = $0219

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
bp_counter_ones .rs 1;
bp_counter_tens .rs 1;
bp_counter_hundreds .rs 1;

MAX_TIME = 9 ; should be 15 seconds. limited bc only count frames to 999 =>16.65
game_over_time .rs 1

FRAMES_PER_TENTH_SEC = 6 ; NTSC is 60 fps
less_than_tenth_sec_counter .rs 1

; Game frame rate
gfr_counter_ones .rs 1
gfr_counter_tens .rs 1
gfr_counter_hundreds .rs 1
; Game seconds counter
game_timer_tenths .rs 1
game_timer_ones .rs 1
game_timer_tens .rs 1

mash_button .rs 1;
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

  LDA #$01
  STA num_players

  LDA #BUTTON_B
  STA mash_button

; TODO make this configurable
  LDA #MAX_TIME
  STA game_over_time

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
  CPX #$40              ; Compare X to hex $20, decimal 32
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

  LDA #%10001000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA PPU_CTRL_REG1

  LDA #%00010000   ; enable sprites, enable background, no clipping on left side
  STA PPU_CTRL_REG2

Forever:
  LDA new_frame
  BEQ FrameProcessed
  LDA #00
  STA new_frame ; reset new frame
  JSR CalcGameFrameCount
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
  CPX game_over_time
  BNE EndGameLogic
  ;;;; Just hit the game over time so call the game over
  LDA #GAME_OVER
  STA game_state
EndGameLogic:

DrawFrameCount:
  LDA game_timer_tenths ; gfr_counter_ones
  STA DIPLAY_GFR_ONES_TILES
  LDA game_timer_ones ; gfr_counter_tens
  STA DIPLAY_GFR_TENS_TILES
  LDA game_timer_tens ; gfr_counter_hundreds
  STA DIPLAY_GFR_HUNDREDS_TILES
DrawButtonPresses:
  LDA bp_counter_ones
  STA DISPLAY_BP_ONES_TILE
  LDA bp_counter_tens
  STA DISPLAY_BP_TENS_TILE
  LDA bp_counter_hundreds
  STA DISPLAY_BP_HUNDREDS_TILE

  RTI             ; return from interrupt

CalcButtonPresses:
  ; Not working :(
  ; LDA p1_buttons_new_press
  ; AND mash_button
  ; BNE DoneBPCalc ; branch if button not down
  LDA p1_buttons
  AND mash_button
  BEQ DoneBPCalc
  LDA p1_prev_buttons
  AND mash_button
  BNE DoneBPCalc
  LDX bp_counter_ones ; We have a new press
  INX
  STX bp_counter_ones
  CPX #$0A
  BNE DoneBPCalc ; if we went over 9
  LDA #00
  STA bp_counter_ones
  LDX bp_counter_tens
  INX ; TODO i think there might be a way to do this in place
  STX bp_counter_tens
  CPX #$0A
  BNE DoneBPCalc ; if we went over 99
  LDA #00
  STA bp_counter_tens
  LDX bp_counter_hundreds
  INX
  STX bp_counter_hundreds
DoneBPCalc:
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

CalcGameFrameCount:
  LDX gfr_counter_ones
  INX
  STX gfr_counter_ones
  CPX #$0A
  BNE DoneFrameCalc ; if we went over 9
  LDA #00
  STA gfr_counter_ones
  LDX gfr_counter_tens
  INX ; TODO i think there might be a way to do this in place
  STX gfr_counter_tens
  CPX #$0A
  BNE DoneFrameCalc ; if we went over 99
  LDA #00
  STA gfr_counter_tens
  LDX gfr_counter_hundreds
  INX
  STX gfr_counter_hundreds
DoneFrameCalc:
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
  ;LDA p1_buttons
  ;EOR #p1_prev_buttons
  ;AND #p1_buttons
  ;STA p1_buttons_new_press
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
  .db $90, $00, $00, $80   ;hundreds frame count ; Currently being used for seconds not frames
  .db $90, $00, $00, $88   ;tens frame count
  .db $90, $00, $00, $90   ;ones frame count
  .db $60, $00, $00, $80   ;tens seconds countdown
  .db $60, $00, $00, $88   ;tens seconds countdown
  .db $60, $00, $00, $90   ;tens seconds countdown

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
