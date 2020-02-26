  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring (horizontal scrolling)

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
PPU_SPR_DMA           = $4014

SND_REGISTER          = $4000
SND_SQUARE1_REG       = $4000
SND_SQUARE2_REG       = $4004
SND_TRIANGLE_REG      = $4008
SND_NOISE_REG         = $400c
SND_DELTA_REG         = $4010
SND_MASTERCTRL_REG    = $4015
SND_FRAME_IRQ         = $4017

CONTROLLER_PORT       = $4016
CONTROLLER_PORT1      = $4016
CONTROLLER_PORT2      = $4017

; ################################
; Game Tiles 0200 not used, used-> 0204->0228
; ################################

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

; ################################
; Menu Tiles 0200->?
; ################################

SCREEN_WIDTH_TILES = 32
SCREEN_HEIGHT_TILES = 30;
; -----------------------------------

  .rsset  $0000   ; start the reserve counter at memory address $0000
dummy .rs 1     ; theres some bug writing to 0000 which is game state...
game_state  .rs 1     ; reserve one byte of space to track the current state
prev_game_state .rs 1 ; to see if state has changed. could hide this in game state
GAME_TITLE = 1
GAME_MENU = 2
GAME_PLAY = 3
GAME_OVER = 4
GAME_SCROLL_TO_GAME = 5
GAME_SCROLL_TO_MENU = 6

GAME_OVER_WAIT_FRAMES = 60
game_over_frame_counter .rs 1

num_players .rs 1 ;

NoiseSoundBuffer .rs 1

; What bit each button is stored in a controller byte
BUTTON_A      = %10000000
BUTTON_B      = %01000000
BUTTON_SELECT = %00100000
BUTTON_START  = %00010000
BUTTON_UP     = %00001000
BUTTON_DOWN   = %00000100
BUTTON_LEFT   = %00000010
BUTTON_RIGHT  = %00000001
BUTTON_DOWN_B  = %01000100 ; for ninja gaiden, mashing down+b together is important for last boss

TOGGLE_BUTTONS = %11010011 ; left/right/b/a/start
TOGGLE_PREV_BUTTONS = %01000010 ; left and b
TOGGLE_NEXT_BUTTONS = %10010001 ; right, a or start

p1_buttons   .rs 1  ; player 1 gamepad buttons, one bit per button
p2_buttons   .rs 1  ; player 2 gamepad buttons, one bit per button
p1_prev_buttons .rs 1 ; to track what buttons changed
p2_prev_buttons .rs 1 ; to track what buttons changed
p1_buttons_new_press .rs 1;
p2_buttons_new_press .rs 1;
p1_in_press .rs 1;
p2_in_press .rs 1;
start_pressed .rs 1 ; TODO this should really not take a full byte

p1_bp_counter_ones .rs 1;
p1_bp_counter_tens .rs 1;
p1_bp_counter_hundreds .rs 1;
p2_bp_counter_ones .rs 1;
p2_bp_counter_tens .rs 1;
p2_bp_counter_hundreds .rs 1;

rate_count_frames .rs 1;
p1_bp_rate_count .rs 1;
p2_bp_rate_count .rs 1;
bp_rate_count_times_4 .rs 1; TODO don't know how to do this any other way

;TODO this is the best way i can think to store the calculated values
p1_bp_rate_ones .rs 1;
p1_bp_rate_tens .rs 1;
p1_bp_rate_tenths .rs 1;
p2_bp_rate_ones .rs 1;
p2_bp_rate_tens .rs 1;
p2_bp_rate_tenths .rs 1;

menu_game_time_s_ones .rs 1
menu_game_time_s_tens .rs 1

FRAMES_PER_TENTH_SEC = 6 ; NTSC is 60 fps
less_than_tenth_sec_counter .rs 1

; Game seconds counter
game_timer_tenths .rs 1
game_timer_ones .rs 1
game_timer_tens .rs 1

mash_button .rs 1;
new_frame .rs 1;
scroll .rs 1;
menu_background_needs_loading .rs 1; not sure better way to do this
background_row .rs 1 ; used to track where in the background data we left off in terms of row number
background_high .rs 1 ; used as local vars to figure out which ppu address to write to
background_low .rs 1 ;
background_data_low .rs 1 ; used to track where in the background data we left off
background_data_high .rs 1

; Menu values
NUM_PLAYERS_1_X = $70
NUM_PLAYERS_2_X = $88
NUM_PLAYER_CHOSER_X = $0207 ; Starts at 0204

REG_MENU_OPTION_CHOOSER_Y = $0200
REG_MENU_OPTION_CHOOSER_X = $0203
MENU_OPTION_CHOOSER_X = $30
MENU_NUM_PLAYERS_Y = $30
MENU_MASH_BUTTON_Y = $40
MENU_SECONDS_Y = $50
MENU_START_Y = $60


;;;;;;;;;;;;;;;

  .bank 0
  .org $C000
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX SND_FRAME_IRQ    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX PPU_CTRL_REG1    ; disable NMI
  STX PPU_CTRL_REG2    ; disable rendering
  STX SND_DELTA_REG    ; disable DMC IRQs

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
  ; Set default value
  LDA #$05
  STA menu_game_time_s_ones
  LDA #$00
  STA menu_game_time_s_tens

  LDA #$01
  STA num_players
  LDA #BUTTON_A
  STA mash_button

  LDA #GAME_TITLE
  STA game_state
  LDA #GAME_TITLE ; TODO want states to disagree so that it'll load the first time
  STA prev_game_state

  LDA #%000001100  ; disable sprites, disable background, no clipping on left side
  STA PPU_CTRL_REG2

  JSR LoadMenuBackground
  JSR LoadTitleBackground

LoadPalettes:
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$3F
  STA PPU_ADDRESS       ; write the high byte of $3F00 address
  LDA #$00
  STA PPU_ADDRESS       ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
  STA PPU_DATA          ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

; if compare was equal to 128, keep going down
  JSR LoadMenuAttribute
  JSR LoadTitleAttribute

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA PPU_CTRL_REG2

  LDA #$00
  STA scroll
  STA background_row
  JSR PushScrollToPPU
  JSR DisplayTitleScreen

Forever:
  LDA new_frame
  BNE ProcessFrame
  JMP Forever
ProcessFrame:
  LDA #00
  STA new_frame ; reset new frame
  LDA game_state
  CMP #GAME_TITLE
  BNE NotTitleLogic
  JSR TitleLogic
NotTitleLogic:
  LDA game_state
  CMP #GAME_SCROLL_TO_GAME
  BNE NotScrollingRight
  JSR IncrementScroll
  STX scroll
  CPX #$00
  BEQ DoneScrollingToGame
  JSR PushScrollToPPU
  JMP FrameProcessed
DoneScrollingToGame:
  LDA #GAME_PLAY
  STA game_state
  JSR PushScrollToPPU  ; Reset scroll to 0
  JSR DisplayScreen1   ; Set to display screen1
  JSR LoadGame         ; load game sprites
  JMP FrameProcessed
NotScrollingRight:
  LDA game_state
  CMP #GAME_SCROLL_TO_MENU
  BNE NotScrolling
  JSR DecrementScroll
  STX scroll
  CPX #$00
  BEQ DoneScrollingToMenu
  JSR PushScrollToPPU
  JMP FrameProcessed
DoneScrollingToMenu:
  LDA #GAME_MENU
  STA game_state
  JSR PushScrollToPPU  ; Reset scroll to 0
  JSR DisplayScreen0   ; Set to display screen 0
  JSR LoadMenu         ; load menu sprites
  JMP FrameProcessed
NotScrolling:
  LDA game_state
  CMP #GAME_PLAY
  BNE TryMenu
  JSR CalcGameTime        ; In game
  JSR CalcButtonPresses
  JSR DrawFrameCount
  JSR RateDisplay
  JMP FrameProcessed
TryMenu:
  LDA game_state
  CMP #GAME_MENU
  BNE TryGameOver
  JSR QueueGameBackground
  JSR MenuLogic
  JMP FrameProcessed
TryGameOver:
  LDA game_state
  CMP #GAME_OVER
  BNE FrameProcessed
  JSR GameOverLogic
  JMP FrameProcessed
FrameProcessed:
  LDX rate_count_frames
  INX
  STX rate_count_frames
  TXA
  AND #%00000111 ; on'y want to decrement so often
  CMP #$00
  BNE RateCountUpdated
  JSR DecrementP1Rate
  JSR DecrementP2Rate
RateCountUpdated:
  JMP Forever     ;jump back to Forever, infinite loop

LoadMenuAttribute:
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$23
  STA PPU_ADDRESS       ; write the high byte of $23C0 address
  LDA #$C0
  STA PPU_ADDRESS       ; write the low byte of $23C0 address
  LDX #$00              ; start out at 0
LoadMenuAttributeLoop:
  LDA game_attribute, x ; normally load data from address (attribute + the value in x)
  STA PPU_DATA          ; write to PPU
  INX                   ; X = X + 1
  CPX #$40              ; 64 total bytes necessary to do full screen
  BNE LoadMenuAttributeLoop
  RTS

LoadGameAttribute:
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$27
  STA PPU_ADDRESS       ; write the high byte of $23C0 address
  LDA #$C0
  STA PPU_ADDRESS       ; write the low byte of $23C0 address
  LDX #$00              ; start out at 0
LoadGameAttributeLoop:
  LDA game_attribute, x ; normally load data from address (attribute + the value in x)
  STA PPU_DATA          ; write to PPU
  INX                   ; X = X + 1
  CPX #$40              ; 64 total bytes necessary to do full screen
  BNE LoadGameAttributeLoop
  RTS

LoadTitleAttribute:
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$27
  STA PPU_ADDRESS       ; write the high byte of $23C0 address
  LDA #$C0
  STA PPU_ADDRESS       ; write the low byte of $23C0 address
  LDX #$00              ; start out at 0
LoadTitleAttributeLoop:
  LDA title_attribute, x ; normally load data from address (attribute + the value in x)
  STA PPUDATA           ; write to PPU
  INX                   ; X = X + 1
  CPX #$40              ; 64 total bytes necessary to do full screen
  BNE LoadTitleAttributeLoop
  RTS

DecrementP1Rate:
  LDX p1_bp_rate_count
  CPX #$00
  BEQ DecrementP1RateDone
  DEX
  STX p1_bp_rate_count
DecrementP1RateDone:
  RTS

DecrementP2Rate:
  LDX p2_bp_rate_count
  CPX #$00
  BEQ DecrementP2RateDone
  DEX
  STX p2_bp_rate_count
DecrementP2RateDone:
  RTS

IncrementP1Rate:
  LDX p1_bp_rate_count
  CPX #$08
  BEQ IncrementP1RateDone
  INX
  STX p1_bp_rate_count
IncrementP1RateDone:
  RTS

IncrementP2Rate:
  LDX p2_bp_rate_count
  CPX #$08
  BEQ IncrementP2RateDone
  INX
  STX p2_bp_rate_count
IncrementP2RateDone:
  RTS

IncrementScroll:
  LDX scroll
  INX
  INX
  INX
  INX
  RTS

DecrementScroll:
  LDX scroll
  DEX
  DEX
  DEX
  DEX
  RTS

DisplayScreen0:
  LDA #%10011000
  STA PPU_CTRL_REG1
  RTS

DisplayScreen1:
  LDA #%10011001
  STA PPU_CTRL_REG1
  RTS

DisplayTitleScreen:
  LDA #%10001001
  STA PPU_CTRL_REG1
  RTS

PushScrollToPPU:
  LDA #$00
  STA PPU_ADDRESS        ; clean up PPU address registers
  STA PPU_ADDRESS
  LDA scroll             ; horizontal scroll full
  STA PPU_SCROLL_REG
  LDA #$00               ; no vertical scrolling
  STA PPU_SCROLL_REG
  RTS

NMI:
  LDA #$00
  STA PPU_SPR_ADDR       ; set the low byte (00) of the RAM address
  LDA #$02
  STA PPU_SPR_DMA        ; set the high byte (02) of the RAM address, start the transfer

  JSR ReadController1
  JSR ReadController2

  LDA #01
  STA new_frame ; Tell forever loop that theres a new set of input to process

; TODO think it'd be better to just load it once and store result in A
GameLogic:
  LDA game_state
  CMP #GAME_PLAY
  BEQ GameLogicPlay
  JMP EndGameLogic
GameLogicPlay:
  LDA game_timer_ones
  CMP menu_game_time_s_ones
  BNE EndGameLogic
  LDA menu_game_time_s_tens
  CMP game_timer_tens
  BNE EndGameLogic
  ;;;; Just hit the game over time so call the game over
  LDA #GAME_OVER
  STA game_state
  JSR DisplayGameOver
  JSR DisplayFinalRate
EndGameLogic:
  RTI             ; return from interrupt

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
  RTS

CalcButtonPresses:
  LDA p1_in_press
  CMP #$01
  BEQ CheckButtonUnPressed
  LDA p1_buttons
  AND mash_button
  CMP mash_button
  BNE P1DoneBPCalc ; branch if button not down
  LDA #$01
  STA p1_in_press ; button is pressed
  ; We have a new press
  JSR IncrementP1Rate
  LDX p1_bp_counter_ones
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
CheckButtonUnPressed:
  LDA p1_buttons
  AND mash_button
  BNE P1DoneBPCalc
  ;; buttons unpressed
  LDA #$00
  STA p1_in_press
P1DoneBPCalc:
  LDA p2_buttons_new_press
  AND mash_button
  BEQ P2DoneBPCalc ; branch if button not down
  JSR IncrementP2Rate
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
  INX
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

GameOverLogic:
  LDX game_over_frame_counter
  CPX #GAME_OVER_WAIT_FRAMES
  BEQ GameOverWaitDone
  INX
  STX game_over_frame_counter
  JMP GameOverLogicDone
GameOverWaitDone:
  JSR DisplayPressStart
  LDA p1_buttons_new_press
  AND #BUTTON_START
  BEQ GameOverLogicDone
  ;; Wait is over and button is pressed so go back to menu
  LDA #GAME_SCROLL_TO_MENU
  STA game_state
  JSR MoveSpritesOffScreen
GameOverLogicDone:
  RTS

MenuLogic:
  LDA REG_MENU_OPTION_CHOOSER_Y
  CMP #MENU_MASH_BUTTON_Y
  BNE NotChoosingMashButton
  LDA #TOGGLE_NEXT_BUTTONS
  AND p1_buttons_new_press
  BEQ NotChoosingNextMashButton
  JSR ToggleNextMashButton
  JMP MenuLogicDone
NotChoosingNextMashButton:
  LDA #TOGGLE_PREV_BUTTONS
  AND p1_buttons_new_press
  BEQ NotChoosingMashButton
  JSR TogglePrevMashButton
  JMP MenuLogicDone
NotChoosingMashButton:
  LDA #BUTTON_SELECT
  ORA #BUTTON_DOWN
  AND p1_buttons_new_press
  BEQ NotToggleMenuDownButton
  JSR ToggleNextMenuItem ; just toggle menu button
  JMP MenuLogicDone
NotToggleMenuDownButton:
  LDA #BUTTON_UP
  AND p1_buttons_new_press
  BEQ NotToggleMenuUpButton
  JSR TogglePrevMenuItem ; just toggle menu button
  JMP MenuLogicDone
NotToggleMenuUpButton:
  LDA REG_MENU_OPTION_CHOOSER_Y
  CMP #MENU_NUM_PLAYERS_Y
  BNE NotToggleNumPlayers
  LDA #TOGGLE_BUTTONS
  AND p1_buttons_new_press
  BEQ NotToggleNumPlayers
  JSR ToggleNumPlayers
  JMP MenuLogicDone
NotToggleNumPlayers:
NotMashButton:
  LDA REG_MENU_OPTION_CHOOSER_Y
  CMP #MENU_SECONDS_Y
  BNE NotMenuSecondsOption
  LDA #TOGGLE_PREV_BUTTONS
  AND p1_buttons_new_press
  BEQ MenuSecOptionCheckIncrease
  JSR TogglePrevTime
  JMP MenuLogicDone
MenuSecOptionCheckIncrease:
  LDA #TOGGLE_NEXT_BUTTONS
  AND p1_buttons_new_press
  BEQ NotMenuSecondsOption
  JSR ToggleNextTime
  JMP MenuLogicDone
MenuSecIncreaseNoFullWrap:
  LDA menu_game_time_s_ones
  CMP #$09
  BNE MenuSecSimpleIncrease
  ; Wrap the tens
  LDA #$00
  STA menu_game_time_s_ones
  LDX menu_game_time_s_tens
  INX
  STX menu_game_time_s_tens
  JMP MenuLogicDone
MenuSecSimpleIncrease:
  LDX menu_game_time_s_ones
  INX
  STX menu_game_time_s_ones
  JMP MenuLogicDone
NotMenuSecondsOption:
  ;if start, if start, start
  LDA REG_MENU_OPTION_CHOOSER_Y
  CMP #MENU_START_Y
  BNE MenuLogicDone
  LDA p1_buttons_new_press
  AND #BUTTON_START
  BEQ MenuLogicDone
  LDA #GAME_SCROLL_TO_GAME ; start the game
  STA game_state
  JSR LoadGameAttribute
  JSR MoveSpritesOffScreen
  JMP MenuLogicDone
MenuLogicDone:
  RTS

ToggleNextMenuItem:
  LDX REG_MENU_OPTION_CHOOSER_Y
  CPX #MENU_START_Y
  BEQ GoBackToFirstMenuItem
  LDA REG_MENU_OPTION_CHOOSER_Y
  CLC      ; clear carry
  ADC #$10 ; shift down 2 16 pixels
  STA REG_MENU_OPTION_CHOOSER_Y
  JMP DoneToggleNextMenuItem
GoBackToFirstMenuItem:
  LDA #MENU_NUM_PLAYERS_Y
  STA REG_MENU_OPTION_CHOOSER_Y
DoneToggleNextMenuItem:
  RTS

TogglePrevMenuItem:
  LDX REG_MENU_OPTION_CHOOSER_Y
  CPX #MENU_NUM_PLAYERS_Y
  BEQ GoBackToLastMenuItem
  LDA REG_MENU_OPTION_CHOOSER_Y
  SEC      ; set clear carry bit
  SBC #$10 ; shift down 2 16 pixels
  STA REG_MENU_OPTION_CHOOSER_Y
  JMP DoneTogglePrevMenuItem
GoBackToLastMenuItem:
  LDA #MENU_START_Y
  STA REG_MENU_OPTION_CHOOSER_Y
DoneTogglePrevMenuItem:
  RTS

; TODO probably a less sloppy way than having separate next/prev
; A->B->Start->Select->Down+B->A
ToggleNextMashButton:
  LDA mash_button
  CMP #BUTTON_A
  BNE ToggleNextMashButtonTryB
  JSR LoadMashButtonB
  JMP EndToggleNextMashButton
ToggleNextMashButtonTryB:
  CMP #BUTTON_B
  BNE ToggleNextMashButtonTryStart
  JSR LoadMashButtonStart
  JMP EndToggleNextMashButton
ToggleNextMashButtonTryStart:
  CMP #BUTTON_START
  BNE ToggleNextMashButtonTrySelect
  JSR LoadMashButtonSelect
  JMP EndToggleNextMashButton
ToggleNextMashButtonTrySelect:
  CMP #BUTTON_SELECT
  BNE ToggleNextMashButtonTryDownB
  JSR LoadMashButtonDownB
  JMP EndToggleNextMashButton
ToggleNextMashButtonTryDownB:
  JSR LoadMashButtonA ; None other to try so no need to verify we're on DownB
EndToggleNextMashButton:
  RTS

; A<-B<-Start<-Select<-Down+B<-A
TogglePrevMashButton:
  LDA mash_button
  CMP #BUTTON_A
  BNE TogglePrevMashButtonTryDownB
  JSR LoadMashButtonDownB
  JMP EndTogglePrevMashButton
TogglePrevMashButtonTryDownB:
  CMP #BUTTON_DOWN_B
  BNE TogglePrevMashButtonTrySelect
  JSR LoadMashButtonSelect
  JMP EndTogglePrevMashButton
TogglePrevMashButtonTrySelect:
  CMP #BUTTON_SELECT
  BNE TogglePrevMashButtonTryStart
  JSR LoadMashButtonStart
  JMP EndTogglePrevMashButton
TogglePrevMashButtonTryStart:
  CMP #BUTTON_START
  BNE TogglePrevMashButtonTryB
  JSR LoadMashButtonB
  JMP EndTogglePrevMashButton
TogglePrevMashButtonTryB:
  JSR LoadMashButtonA ; None other to try so no need to verify we're on B
EndTogglePrevMashButton:
  RTS

ToggleNumPlayers:
  LDA num_players
  EOR #%00000011 ; ignore first 6 bits. last two either 1 or 2 (01 or 10)
  STA num_players
  JSR UpdateNumPlayersArrow
  RTS

UpdateNumPlayersArrow:
  LDA num_players
  CMP #$02
  BEQ UpdateNumPlayersArrowTo2
  LDA #NUM_PLAYERS_1_X
  STA NUM_PLAYER_CHOSER_X
  JMP UpdateNumPlayersArrowDone
UpdateNumPlayersArrowTo2:
  LDA #NUM_PLAYERS_2_X
  STA NUM_PLAYER_CHOSER_X
UpdateNumPlayersArrowDone:
  RTS

TogglePrevTime:
  LDA menu_game_time_s_ones
  CMP #$00 ; 10
  BEQ ToggleTimeTo5
  CMP #$05 ; 5
  BEQ ToggleTimeTo2
  CMP #$02 ; 2
  BEQ ToggleTimeTo1
  ; we know we're at 1
  JMP ToggleTimeTo10
ToggleNextTime:
  LDA menu_game_time_s_ones
  CMP #$00 ; 10
  BEQ ToggleTimeTo1
  CMP #$05 ; 5
  BEQ ToggleTimeTo10
  CMP #$02 ; 2
  BEQ ToggleTimeTo5
  ; we know we're at 1
  JMP ToggleTimeTo2
ToggleTimeTo1:
  LDA #$01
  STA menu_game_time_s_ones
  LDA #$00
  STA menu_game_time_s_tens
  JMP UpdateMenuTime
ToggleTimeTo2:
  LDA #$02
  STA menu_game_time_s_ones
  LDA #$00
  STA menu_game_time_s_tens
  JMP UpdateMenuTime
ToggleTimeTo5:
  LDA #$05
  STA menu_game_time_s_ones
  LDA #$00
  STA menu_game_time_s_tens
  JMP UpdateMenuTime
ToggleTimeTo10:
  LDA #$00
  STA menu_game_time_s_ones
  LDA #$01
  STA menu_game_time_s_tens
  JMP UpdateMenuTime
UpdateMenuTime:
  LDA menu_game_time_s_ones
  STA $020D
  LDA menu_game_time_s_tens
  STA $0209
  RTS

LoadMenu:
LoadMenuOptionChooser:
  LDA #MENU_NUM_PLAYERS_Y
  STA REG_MENU_OPTION_CHOOSER_Y
  LDA #$28 ; Arrow
  STA $0201 ; This whole block is a mess
  LDA #$00 ; attribute
  STA $0202
  LDA #$18 ; X position
  STA $0203
LoadNumPlayerArrow:
  LDX #$00              ; start at 0
LoadNumPlayerArrowLoop:
  LDA num_player_arrow, x        ; load data from address (sprites +  x)
  STA $0204, x                   ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$04              ;
  BNE LoadNumPlayerArrowLoop

  JSR UpdateNumPlayersArrow

LoadMenuGameTime:
  LDX #$00
LoadMenuGameTimeLoop:
  LDA menu_game_time, x
  STA $0208, x
  INX
  CPX #$08              ; 2 sprites (tens and ones)
  BNE LoadMenuGameTimeLoop
  JSR UpdateMenuTime

LoadMashButtonDisplay:
  LDX #$00
LoadMashButtonDisplayLoop:
  LDA menu_button_choice, x
  STA $0210, x
  INX
  CPX #$18              ; 6 sprites (MAX word is 'select')
  BNE LoadMashButtonDisplayLoop

  ;TODO this is hacky. do this smarter
  JSR ToggleNextMashButton
  JSR TogglePrevMashButton
  RTS

LoadMenuBackground:
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$20
  STA PPU_ADDRESS       ; write the high byte of $2000 address
  LDA #$00
  STA PPU_ADDRESS       ; write the low byte of $2000 address
  LDX #$00              ; start out at 0
LoadMenuBackground1Loop:
  LDA menu_background_1, x; load data from address (background + the value in x)
  STA PPU_DATA          ; write to PPU
  INX                   ; X = X + 1
  CPX #$00              ; load all background tiles
  BNE LoadMenuBackground1Loop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
LoadMenuBackground2Loop:
  LDA menu_background_2, x; load data from address (background + the value in x)
  STA PPU_DATA          ; write to PPU
  INX                   ; X = X + 1
  CPX #$00              ; load all background tiles
  BNE LoadMenuBackground2Loop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
LoadMenuBackground3Loop:
  LDA menu_background_3, x; load data from address (background + the value in x)
  STA PPU_DATA          ; write to PPU
  INX                   ; X = X + 1
  CPX #$00              ; load all background tiles
  BNE LoadMenuBackground3Loop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
LoadMenuBackground4Loop:
  LDA menu_background_4, x; load data from address (background + the value in x)
  STA PPU_DATA          ; write to PPU
  INX                   ; X = X + 1
  CPX #$C0              ; load all background tiles 6*32 = xC0
  BNE LoadMenuBackground4Loop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
  RTS

LoadGameBackgroundRow:
  ; 256 / (4 bytes per sprite) = 64 bytes per low pointer locations
  LDA background_row
  LSR A
  LSR A
  LSR A  ; divide by 8 to get the high pointer location
  CLC
  ADC #$24                   ; all highs start at 24 (low starts at 0)
  STA background_high
  LDA background_row
  AND #%00001111           ; take mod 8 to get the low pointer location
  CLC
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A                    ; multiply by 32 to get the starting low point
  STA background_low
  ;; Setup the location to write to
  LDA PPU_STATUS
  LDA background_high
  STA PPU_ADDRESS
  LDA background_low
  STA PPU_ADDRESS
  ;; Setup the background data to write to it
  LDA background_low
  CLC
  ADC #LOW(game_background)
  STA background_data_low
  LDA background_high
  ADC #HIGH(game_background) ; includes carry from the low add
  SEC
  SBC #$24      ; really hacky, but high has the extra 24 tacked on because its a ppu address
  STA background_data_high
  LDY #$00
LoadGameBackgroundRowLoop:
  LDA [background_data_low], y
  STA PPU_DATA
  INY
  CPY #$40 ; 64
  BNE LoadGameBackgroundRowLoop
  LDX background_row
  INX
  STX background_row
  CPX #$1E  ; 30
  BNE LoadGameBackgroundRowDone
  LDX #$00
  STX menu_background_needs_loading
  STX background_row
LoadGameBackgroundRowDone:
  LDA #$00
  STA PPU_SCROLL_REG
  STA PPU_SCROLL_REG
  RTS

TitleLogic:
  LDA p1_buttons_new_press
  AND #BUTTON_START
  CMP #$00
  BEQ TitleLogicDone
  LDA #GAME_MENU
  STA game_state
  LDA #$01
  STA menu_background_needs_loading ; mark menu to be loaded
  JSR LoadMenu
  JSR DisplayScreen0
TitleLogicDone:
  RTS

QueueGameBackground:
  LDA menu_background_needs_loading
  CMP #$00
  BEQ QueueGameBackgroundDone

  LDA #%000001100  ; disable sprites, disable background, no clipping on left side
  STA PPU_CTRL_REG2

  JSR LoadGameBackgroundRow
  JSR DisplayScreen0 ; don't know why above is changing screen, but this will fix it

  LDA #%000111100  ; enable sprites, enable background, no clipping on left side
  STA PPU_CTRL_REG2
QueueGameBackgroundDone:
  RTS

LoadTitleBackground:
  LDA PPU_STATUS
  LDA #$24
  STA PPU_ADDRESS
  LDA #$00
  STA PPU_ADDRESS
  LDX #$00
LoadTitleBackground1Loop:
  LDA title_background_1, x
  STA PPU_DATA
  INX
  CPX #$00
  BNE LoadTitleBackground1Loop
LoadTitleBackground2Loop:
  LDA title_background_2, x
  STA PPU_DATA
  INX
  CPX #$00
  BNE LoadTitleBackground2Loop
LoadTitleBackground3Loop:
  LDA title_background_3, x
  STA PPU_DATA
  INX
  CPX #$00
  BNE LoadTitleBackground3Loop
LoadTitleBackground4Loop:
  LDA title_background_4, x
  STA PPU_DATA
  INX
  CPX #$C0
  BNE LoadTitleBackground4Loop
  RTS

LoadGame:
  JSR MoveSpritesOffScreen ; TODO make sure this happens the same sort of way of going back to menu

  LDA #$00
  STA game_timer_tenths
  STA game_timer_ones
  STA game_timer_tens
  STA game_over_frame_counter
  STA p1_in_press
  STA p2_in_press
  STA p1_bp_rate_count

LoadP1Sprites:
  LDX #$00              ; start at 0
LoadP1SpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0204, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$1C              ; Compare X to hex $1C, decimal 28 -> 7 chars, 4 bytes each
  BNE LoadP1SpritesLoop

  LDA #$00
  STA p1_bp_counter_ones
  STA p1_bp_counter_tens
  STA p1_bp_counter_hundreds
  STA p2_bp_counter_ones
  STA p2_bp_counter_tens
  STA p2_bp_counter_hundreds

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
  CPX #$0C            ; 3 sprites
  BNE LoadP1LabelLoop
  RTS

DisplayGameOver:
  LDX #$00
DisplayGameTextLoop:
  LDA game_text, x
  STA $0244, x
  INX
  CPX #$10 ; 16 -> 4 sprites
  BNE DisplayGameTextLoop
  LDX #$00
DisplayOverTextLoop:
  LDA over_text, x
  STA $0254, x
  INX
  CPX #$10 ; 16 -> 4 sprites
  BNE DisplayOverTextLoop
  RTS

DisplayPressStart:
  LDX #$00
DisplayPressTextLoop:
  LDA press_text, x
  STA $02A4, x
  INX
  CPX #$14 ; 20 -> 5 sprites
  BNE DisplayPressTextLoop
  LDX #$00
DisplayStartTextLoop:
  LDA start_press_text, x
  STA $02B8, x
  INX
  CPX #$14 ; 20 -> 5 sprites
  BNE DisplayStartTextLoop
  RTS

DisplayFinalRate:
  JSR DisplayP1FinalRate
  LDA num_players
  CMP #$02
  BNE DisplayFinalRateSkipP2
  JSR DisplayP2FinalRate
DisplayFinalRateSkipP2:
  RTS

DisplayP1FinalRate:
  JSR CalculateP1FinalRate
  LDX #$00
DisplayP1FinalRateLoop:
  LDA p1_final_rate, x
  STA $02CC, x
  INX
  CPX #$18      ; 6 sprites, but skip decimal below
  BNE DisplayP1FinalRateLoop
  LDA p1_bp_rate_tens
  STA $02CD
  LDA p1_bp_rate_ones
  STA $02D1
  LDA p1_bp_rate_tenths
  STA $02D9
  RTS

DisplayP2FinalRate:
  JSR CalculateP2FinalRate
  LDX #$00
DisplayP2FinalRateLoop:
  LDA p2_final_rate, x
  STA $02E4, x
  INX
  CPX #$18     ; 4 sprites, but skip decimal below
  BNE DisplayP2FinalRateLoop
  LDA p2_bp_rate_tens
  STA $02E5
  LDA p2_bp_rate_ones
  STA $02E9
  LDA p2_bp_rate_tenths
  STA $02F1
DisplayP2FinalRateDone:
  RTS

CalculateP1FinalRate:
  LDA menu_game_time_s_ones
  CMP #$01
  BNE CalculateP1FinalRateTry2
  JSR CalculateP1FinalRate_1_Sec
  JMP CalculateP1FinalRateDone
CalculateP1FinalRateTry2:
  CMP #$02
  BNE CalculateP1FinalRateTry5
  JSR CalculateP1FinalRate_2_Sec
  JMP CalculateP1FinalRateDone
CalculateP1FinalRateTry5:
  CMP #$05
  BNE CalculateP1FinalRateTry10
  JSR CalculateP1FinalRate_5_Sec
  JMP CalculateP1FinalRateDone
CalculateP1FinalRateTry10: ; None left so it is 10
  JSR CalculateP1FinalRate_10_Sec
CalculateP1FinalRateDone:
  RTS

CalculateP1FinalRate_1_Sec:
  LDA p1_bp_counter_ones
  STA p1_bp_rate_ones
  LDA p1_bp_counter_tens
  STA p1_bp_rate_tens
  LDA #$00
  STA p1_bp_rate_tenths
  RTS

CalculateP1FinalRate_2_Sec: ; 2x30 = 60 max
  LDA p1_bp_counter_ones
  LSR A
  STA p1_bp_rate_ones ; TODO account for odd tens
  LDA #$00
  STA p1_bp_rate_tenths
  BCC P1FinalRate2SecNoOnesCarry ; if ones shift left a carry, add 5 to tenths
  CLC
  ADC #$05
  STA p1_bp_rate_tenths
P1FinalRate2SecNoOnesCarry:
  LDA p1_bp_counter_tens
  LSR A
  STA p1_bp_rate_tens
  BCC P1FinalRate2SecNoTensCarry
  LDA p1_bp_rate_ones ; Add the 5 carry over
  CLC
  ADC #$05
  STA p1_bp_rate_ones
P1FinalRate2SecNoTensCarry:
  RTS

CalculateP1FinalRate_5_Sec: ; max is 5*30 = 150. Mult by 2 then divide by 10
  LDA p1_bp_counter_hundreds
  ASL A
  STA p1_bp_rate_tens
  LDA p1_bp_counter_tens
  ASL A
  STA p1_bp_rate_ones
  CMP #$0A
  BCC CalcP1FinalRate5SecTensLess10
  SBC #$0A ; Shouldn't be more than 18 so only need to subtract 10
  STA p1_bp_rate_ones
  LDX p1_bp_rate_tens
  INX
  STX p1_bp_rate_tens
CalcP1FinalRate5SecTensLess10:
  LDA p1_bp_counter_ones
  ASL A
  STA p1_bp_rate_tenths
  CMP #$0A
  BCC CalcP1FinalRateDone
  SBC #$0A
  STA p1_bp_rate_tenths
  LDX p1_bp_rate_ones
  INX
  STX p1_bp_rate_ones
CalcP1FinalRateDone:
  RTS

CalculateP1FinalRate_10_Sec:
  LDA p1_bp_counter_hundreds
  STA p1_bp_rate_tens
  LDA p1_bp_counter_tens
  STA p1_bp_rate_ones
  LDA p1_bp_counter_ones
  STA p1_bp_rate_tenths
  RTS

; TODO there has to be a better way than duplicating all this logic for the p2 rate
CalculateP2FinalRate:
  LDA menu_game_time_s_ones
  CMP #$01
  BNE CalculateP2FinalRateTry2
  JSR CalculateP2FinalRate_1_Sec
  JMP CalculateP2FinalRateDone
CalculateP2FinalRateTry2:
  CMP #$02
  BNE CalculateP2FinalRateTry5
  JSR CalculateP2FinalRate_2_Sec
  JMP CalculateP2FinalRateDone
CalculateP2FinalRateTry5:
  CMP #$05
  BNE CalculateP2FinalRateTry10
  JSR CalculateP2FinalRate_5_Sec
  JMP CalculateP2FinalRateDone
CalculateP2FinalRateTry10: ; None left so it is 10
  JSR CalculateP2FinalRate_10_Sec
CalculateP2FinalRateDone:
  RTS

CalculateP2FinalRate_1_Sec:
  LDA p2_bp_counter_ones
  STA p2_bp_rate_ones
  LDA p2_bp_counter_tens
  STA p2_bp_rate_tens
  LDA #$00
  STA p2_bp_rate_tenths
  RTS

CalculateP2FinalRate_2_Sec: ; 2x30 = 60 max
  LDA p2_bp_counter_ones
  LSR A
  STA p2_bp_rate_ones ; TODO account for odd tens
  LDA #$00
  STA p2_bp_rate_tenths
  BCC P2FinalRate2SecNoOnesCarry ; if ones shift left a carry, add 5 to tenths
  CLC
  ADC #$05
  STA p2_bp_rate_tenths
P2FinalRate2SecNoOnesCarry:
  LDA p2_bp_counter_tens
  LSR A
  STA p2_bp_rate_tens
  BCC P2FinalRate2SecNoTensCarry
  LDA p2_bp_rate_ones ; Add the 5 carry over
  CLC
  ADC #$05
  STA p2_bp_rate_ones
P2FinalRate2SecNoTensCarry:
  RTS

CalculateP2FinalRate_5_Sec: ; max is 5*30 = 150. Mult by 2 then divide by 10
  LDA p2_bp_counter_hundreds
  ASL A
  STA p2_bp_rate_tens
  LDA p2_bp_counter_tens
  ASL A
  STA p2_bp_rate_ones
  CMP #$0A
  BCC CalcP2FinalRate5SecTensLess10
  SBC #$0A ; Shouldn't be more than 18 so only need to subtract 10
  STA p2_bp_rate_ones
  LDX p2_bp_rate_tens
  INX
  STX p2_bp_rate_tens
CalcP2FinalRate5SecTensLess10:
  LDA p2_bp_counter_ones
  ASL A
  STA p2_bp_rate_tenths
  CMP #$0A
  BCC CalcP2FinalRateDone
  SBC #$0A
  STA p2_bp_rate_tenths
  LDX p2_bp_rate_ones
  INX
  STX p2_bp_rate_ones
CalcP2FinalRateDone:
  RTS

CalculateP2FinalRate_10_Sec:
  LDA p2_bp_counter_hundreds
  STA p2_bp_rate_tens
  LDA p2_bp_counter_tens
  STA p2_bp_rate_ones
  LDA p2_bp_counter_ones
  STA p2_bp_rate_tenths
  RTS

  ; End p2 rate logic

RateDisplay:
  JSR P1RateDisplay
  LDA num_players
  CMP #$02
  BNE RateDisplaySkipP2
  JSR P2RateDisplay
RateDisplaySkipP2:
  RTS

;TODO small bug where if it goes back to 0, something shows up
P1RateDisplay:
  LDA p1_bp_rate_count
  CMP #$00
  BEQ P1RateHideLoop
  ASL A
  ASL A
  STA bp_rate_count_times_4
  LDX #$00
P1RateDisplayLoop:
  LDA p1_rate_meter, x
  STA $0264, x
  INX
  CPX bp_rate_count_times_4 ; 32 -> 8 sprites
  BNE P1RateDisplayLoop
  CPX #$20
  BEQ P1RateDisplayDone ; if we already drew 8 sprites, then skip the 'hide' state
P1RateHideLoop:
  LDA #$F8
  STA $0264, x
  INX
  CPX #$20
  BNE P1RateHideLoop ; TODO this will always write over the last sprite
P1RateDisplayDone:
  RTS

P2RateDisplay:
  LDA p2_bp_rate_count
  CMP #$00
  BEQ P2RateHideLoop
  ASL A
  ASL A
  STA bp_rate_count_times_4
  LDX #$00
P2RateDisplayLoop:
  LDA p2_rate_meter, x
  STA $0284, x
  INX
  CPX bp_rate_count_times_4 ; 32 -> 8 sprites
  BNE P2RateDisplayLoop
  CPX $20
  BEQ P2RateDisplayDone ; if we already drew 8 sprites, then skip the 'hide' state
P2RateHideLoop:
  LDA #$F8
  STA $0284, x
  INX
  CPX #$20
  BNE P2RateHideLoop ; TODO this will always write over the last sprite
P2RateDisplayDone:
  RTS

; TODO there has to be a better way to do this
LoadMashButtonDownB:
  LDA #BUTTON_DOWN_B
  STA mash_button
  LDX #$00
  LDY #$00
LoadMashButtonDownBLoop:
  LDA down_b_text, x
  STA $0211, y
  INX
  INY
  INY
  INY
  INY ; There has to be a better way to do this
  CPX #$06
  BNE LoadMashButtonDownBLoop
  RTS

LoadMashButtonA:
  LDA #BUTTON_A
  STA mash_button
  LDX #$00
  LDY #$00
LoadMashButtonALoop:
  LDA a_text, x
  STA $0211, y
  INX
  INY
  INY
  INY
  INY ; There has to be a better way to do this
  CPX #$06
  BNE LoadMashButtonALoop
  RTS

LoadMashButtonB:
  LDA #BUTTON_B
  STA mash_button
  LDX #$00
  LDY #$00
LoadMashButtonBLoop:
  LDA b_text, x
  STA $0211, y
  INX
  INY
  INY
  INY
  INY ; There has to be a better way to do this
  CPX #$06
  BNE LoadMashButtonBLoop
  RTS

LoadMashButtonSelect:
  LDA #BUTTON_SELECT
  STA mash_button
  LDX #$00
  LDY #$00
LoadMashButtonSelectLoop:
  LDA select_text, x
  STA $0211, y
  INX
  INY
  INY
  INY
  INY ; There has to be a better way to do this
  CPX #$06
  BNE LoadMashButtonSelectLoop
  RTS

LoadMashButtonStart:
  LDA #BUTTON_START
  STA mash_button
  LDX #$00
  LDY #$00
LoadMashButtonStartLoop:
  LDA start_text, x
  STA $0211, y
  INX
  INY
  INY
  INY
  INY ; There has to be a better way to do this
  CPX #$06
  BNE LoadMashButtonStartLoop
  RTS

MoveSpritesOffScreen:
  LDX #$00
  LDA #$F0                      ; Off screen in Y direction
MoveSpritesOffScreenLoop:
  STA $0200, x                  ; Put all sprites in a Y off screen position
  INX
  INX
  INX
  INX
  CPX #$00                      ; 0 == 256 -> 4*(64 sprites)
  BNE MoveSpritesOffScreenLoop
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
  .org $D000
  .org $E000
palette:
  .db $0F,$30,$07,$16,$0F,$10,$00,$16,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F ;background palette data
  .db $0F,$30,$07,$16,$31,$02,$38,$3C,$0F,$1C,$15,$14,$31,$02,$38,$3C ;sprite palette data

press_b_to_start:
  .db $19,$1B

sprites:
     ;vert tile attr horiz
  .db $50, $00, $00, $80   ;p1 hundreds bp count
  .db $50, $00, $00, $88   ;p1 tens bp count
  .db $50, $00, $00, $90   ;p1 ones bp count
  .db $60, $00, $00, $78   ;tens game timer
  .db $60, $00, $00, $80   ;ones game timer
  .db $60, $AF, $00, $88   ;decimal point
  .db $60, $00, $00, $90   ;tenths game timer

p2_sprites:
  .db $70, $00, $00, $80   ;p2 hundreds game timer
  .db $70, $00, $00, $88   ;p2 tens game timer
  .db $70, $00, $00, $90   ;p2 ones game timer
  .db $70, $19, $00, $60   ; 'p' TODO these should go in the background
  .db $70, $02, $00, $68   ; '2'
  .db $70, $28, $00, $70   ; '-'

p1_label:
  .db $50, $19, $00, $60   ; 'p' TODO these should go in the background
  .db $50, $01, $00, $68   ; '1'
  .db $50, $28, $00, $70   ; '-'

num_player_arrow:
  .db $30, $28, $00, $70

menu_game_time:
  .db $50, $01, $00, $88   ;tens
  .db $50, $02, $00, $90   ;ones

menu_button_choice:
  .db $40, $0A, $00, $78
  .db $40, $0A, $00, $80
  .db $40, $0A, $00, $88
  .db $40, $0A, $00, $90
  .db $40, $0A, $00, $98
  .db $40, $0A, $00, $A0

game_text:
  .db $A0, $10, $00, $58
  .db $A0, $0A, $00, $60
  .db $A0, $16, $00, $68
  .db $A0, $0E, $00, $70

over_text:
  .db $A0, $18, $00, $80
  .db $A0, $1F, $00, $88
  .db $A0, $0E, $00, $90
  .db $A0, $1B, $00, $98

press_text:
  .db $B0, $19, $00, $68
  .db $B0, $1B, $00, $70
  .db $B0, $0E, $00, $78
  .db $B0, $1C, $00, $80
  .db $B0, $1C, $00, $88

start_press_text: ; Don't love this name, but start_text is already used
  .db $B8, $1C, $00, $68
  .db $B8, $1D, $00, $70
  .db $B8, $0A, $00, $78
  .db $B8, $1B, $00, $80
  .db $B8, $1D, $00, $88

up_text:
  .db $1E, $19, $24, $24, $24, $24

down_text:
  .db $0D, $18, $20, $17, $24, $24

left_text:
  .db $15, $0E, $0F, $1D, $24, $24

right_text:
  .db $1B, $12, $10, $11, $1D, $24

start_text:
  .db $1C, $1D, $0A, $1B, $1D, $24

select_text:
  .db $1C, $0E, $15, $0E, $0C, $1D

a_text:
  .db $0A, $24, $24, $24, $24, $24

b_text:
  .db $0B, $24, $24, $24, $24, $24

down_b_text:
  .db $0D, $18, $20, $17, $2A, $0B

rate_meter: ; TODO unused
  .db $30, $31, $32, $33, $34, $35, $36, $37

p1_final_rate:
  .db $58, $00, $00, $A8   ;tens game timer
  .db $58, $00, $00, $B0   ;ones game timer
  .db $58, $AF, $00, $B8   ;decimal point
  .db $58, $00, $00, $C0   ;tenths game timer
  .db $58, $38, $00, $C8   ; slash
  .db $58, $39, $00, $D0   ; s  (for the '/s')

p1_rate_meter:
  .db $30, $30, $00, $58
  .db $30, $31, $00, $60
  .db $30, $32, $00, $68
  .db $30, $33, $00, $70
  .db $30, $34, $00, $78
  .db $30, $35, $00, $80
  .db $30, $36, $00, $88
  .db $30, $37, $00, $90

p2_final_rate:
  .db $78, $00, $00, $A8   ;tens game timer
  .db $78, $00, $00, $B0   ;ones game timer
  .db $78, $AF, $00, $B8   ;decimal point
  .db $78, $00, $00, $C0   ;tenths game timer
  .db $78, $38, $00, $C8   ; slash
  .db $78, $39, $00, $D0   ; s  (for the '/s')

p2_rate_meter:
  .db $90, $30, $00, $58
  .db $90, $31, $00, $60
  .db $90, $32, $00, $68
  .db $90, $33, $00, $70
  .db $90, $34, $00, $78
  .db $90, $35, $00, $80
  .db $90, $36, $00, $88
  .db $90, $37, $00, $90

menu_background_1:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 1
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 2
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 3
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 4
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 5
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 6
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$19,$15,$0A,$22,$0E,$1B,$1C,$24,$24,$24,$01  ;;row 7 Players
  .db $24,$24,$02,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 8
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
menu_background_2:
  .db $24,$24,$24,$24,$24,$24,$0B,$1E,$1D,$1D,$18,$17,$24,$24,$24,$24  ;;row 9 Button
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 10
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$1C,$0E,$0C,$18,$17,$0D,$1C,$24,$24,$24,$24  ;;row 11 Seconds
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 12
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$24,$24,$1C,$1D,$0A,$1B,$1D,$24,$24,$24,$24  ;;row 13 Start
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 14
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 15
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 16
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
menu_background_3:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 17
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 18
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 19
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 20
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 21
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 22
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 23
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 24
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
menu_background_4:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 25
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 29
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 28
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 29
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 30
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24

game_background:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 1
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 2
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 3
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 4
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 5
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 6
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 7
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 8
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 9
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24  ;;row 10
  .db $24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24,$24  ;;row 11
  .db $24,$24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24  ;;row 12
  .db $24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24,$24  ;;row 13
  .db $24,$24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24  ;;row 14
  .db $24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24,$24  ;;row 15
  .db $24,$24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24  ;;row 16
  .db $24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 17
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 18
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 19
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 20
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 21
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 22
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 23
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 24
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 25
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 27
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 28
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 29
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 30
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24

title_background_1:
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 1
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 2
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 3
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 4
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$60,$61,$62,$63,$64,$65,$66,$67,$68,$69,$6A,$6B,$6C  ;;row 5
  .db $60,$61,$62,$63,$64,$65,$66,$67,$68,$69,$6A,$6B,$6C,$0A,$0A,$0A
  .db $0A,$0A,$0A,$70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$7A,$7B,$7C  ;;row 6
  .db $70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$7A,$7B,$7C,$0A,$0A,$0A
  .db $0A,$0A,$0A,$80,$81,$82,$83,$84,$85,$86,$87,$88,$89,$8A,$8B,$8C  ;;row 7
  .db $80,$81,$82,$83,$84,$85,$86,$87,$88,$89,$8A,$8B,$8C,$0A,$0A,$0A
  .db $0A,$0A,$0A,$90,$91,$92,$93,$94,$95,$96,$97,$98,$99,$9A,$9B,$9C  ;;row 8
  .db $90,$91,$92,$93,$94,$95,$96,$97,$98,$99,$9A,$9B,$9C,$0A,$0A,$0A
title_background_2:
  .db $0A,$0A,$0A,$A0,$A1,$A2,$A3,$A4,$A5,$A6,$A7,$A8,$A9,$AA,$AB,$AC  ;;row 9
  .db $A0,$A1,$A2,$A3,$A4,$A5,$A6,$A7,$A8,$A9,$AA,$AB,$AC,$0A,$0A,$0A
  .db $0A,$0A,$0A,$B0,$B1,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$BA,$BB,$BC  ;;row 10
  .db $B0,$B1,$B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$BA,$BB,$BC,$0A,$0A,$0A
  .db $0A,$0A,$0A,$C0,$C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC  ;;row 11
  .db $C0,$C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 12
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 13
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$00,$01,$02,$03,$04  ;;row 14 Controller
  .db $05,$06,$07,$08,$09,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$10,$11,$12,$13,$14  ;;row 15 Controller
  .db $15,$16,$17,$18,$19,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$20,$21,$22,$23,$24  ;;row 16 Controller
  .db $25,$26,$27,$28,$29,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
title_background_3:
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$30,$31,$32,$33,$34  ;;row 17 Controller
  .db $35,$36,$37,$38,$39,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$40,$41,$42,$43,$44  ;;row 18 Controller
  .db $45,$46,$47,$48,$49,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$50,$51,$52,$53,$54  ;;row 19 Controller
  .db $55,$56,$57,$58,$59,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 20
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 21
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$E9,$EB,$DE,$EC,$EC,$0A  ;;row 22 press start
  .db $0A,$EC,$ED,$DA,$EB,$ED,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 23
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 24
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
title_background_4:
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$E7,$E8,$ED,$0A,$ED,$E6  ;;row 24 Not TM nor C
  .db $0A,$E7,$E8,$EB,$0A,$FF,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$DA,$0A,$E6,$E2,$ED,$DC,$E1  ;;row 26 A Mitch3a Game
  .db $D3,$DA,$0A,$E0,$DA,$E6,$DE,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$E0,$E2,$ED,$E1,$EE,$DB,$F9,$DC,$E8,$E6,$F8,$E6,$E2,$ED,$DC  ;;row 27 github link
  .db $E1,$D3,$DB,$F8,$E6,$DA,$EC,$E1,$F2,$E6,$DA,$EC,$E1,$F2,$0A,$0A
  .db $0A,$0A,$0A,$0A,$E7,$E8,$ED,$0A,$E5,$E2,$DC,$DE,$E7,$EC,$DE,$DD  ;;row 28 not licensed by nintendo
  .db $0A,$DB,$F2,$0A,$E7,$E2,$E7,$ED,$DE,$E7,$DD,$E8,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 29
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ;;row 30
  .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A

game_attribute:
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;1x4 rows (0-3)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;2x4 rows (4-7)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;3x4 rows (8-11)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;4x4 rows (12-15)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;5x4 rows (16-19)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;6x4 rows (20-23)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;7x4 rows (24-27)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;8x4 rows (28-30)

title_attribute:
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;1x4 rows (0-3)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;2x4 rows (4-7)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;3x4 rows (8-11)
  .db %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101 ;4x4 rows (12-15)
  .db %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101, %01010101 ;5x4 rows (16-19)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;6x4 rows (20-23)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;7x4 rows (24-27)
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;8x4 rows (28-30)

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used

;;;;;;;;;;;;;;

  .bank 2
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1
