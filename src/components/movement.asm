.include "constants.asm"
.include "globals.asm"
.include "macros.asm"

.export create_movement_component
.export init_movement_components
.export update_movement_components

; movement component
; size -> 5 byte

.rodata
MOVE_COMP_SIZE = 5

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; movement_component:
;    .addr owner                     ; entity -> contains x and y position
;    .byte speed
;    .byte dirX, dirY
; movement rule
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; update all movements

; container for 25 movement components
; addresses or data? -> addresses

.segment "BSS"
movement_component_container: .res 150

num_movement_components: .res 1


.code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INIT CODE .. reset all variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
init_movement_components:
    lda #$00
    sta num_movement_components
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; create movement components
; ARGS:
;   var_1               - xPosition
;   var_2               - yPosition
;   var_3               - xDir
;   var_4               - yDir, now one byte will be reduced
;   var_5               - speed

;   address_1           - owner
;
; RETURN:
;   address_2           - address of movement_component
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.proc create_movement_component
    ; calculate offset in current component buffer
    mult_with_constant num_movement_components, #MOVE_COMP_SIZE, var_5

    calc_address_with_offset movement_component_container, var_5, address_2 ; use address_2 as address_3 is return address

    ldy #$00                                ; owner lo
    lda address_1
    sta (address_2), y

    iny
    lda address_1 + 1                       ; owner hi
    sta (address_2), y
    iny

    lda var_5                               ; speed
    sta (address_2), y
    iny

    lda var_3                               ; dirX
    sta (address_2), y
    iny

    lda var_4                               ; dirY
    sta (address_2), y
    iny

    inc num_movement_components
    rts
.endproc


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; update movement components
; ARGS:
;
; RETURN:
;   address_1             - updated movement component
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.proc update_movement_components
    ; calculate max value and store it in var_1
    mult_with_constant num_movement_components, #MOVE_COMP_SIZE, var_1

    lda num_movement_components
    sta var_1

    lda #<movement_component_container
    sta address_1

    lda #>movement_component_container
    sta address_1 + 1

    ldy #$00

@update_mov_comp:
    lda var_1
    cmp #$00
    bne :+
    rts                                     ; return if no components are left
:   lda (address_1), y                      ; Get entity address lo byte
    sta address_2
    iny

    lda (address_1), y                      ; Get entity address hi byte
    sta address_2 + 1
    iny

    tya                                     ; push y to stack
    pha

    ldy #$00                                ; get x, y position from the entity
    lda (address_2), y
    sta var_2
    iny

    lda (address_2), y
    sta var_3
    iny
    iny                                     ; jump over components

    lda (address_2), Y                      ; check if movement component is active
    sta var_5

    pla                                     ; get y offset from stack again
    tay

    lda #MOVEMENT_CMP
    bit var_5
    bne :+                                  ; jump to next vomponent
    iny
    iny
    iny
    dec var_1
    jmp @update_mov_comp

:   lda (address_1), y
    sta var_4                               ; speed
    iny

    lda (address_1), Y
    sta var_5                               ; dirX
    iny

    lda (address_1), Y
    sta var_6                               ; dirY
    iny

    tya
    pha

    ; mult_variables var_5, var_4, var_7      ; calculate offset in x direction
    ldx #$00
    ldy #$00
    lda var_2
    sta var_8
    clc
    adc var_5
    sta (address_2), y                      ; store new x pos
    sta var_7

    lda var_5
    sta var_9

    iny
    lda var_3                               ; add speed to previous position
    sta var_8
    clc
    adc var_6
    sta var_7

    lda var_6
    sta var_9
    ldx #$00
    jsr check_for_overflow

    cpx #$01
    bcc :+
    lda var_3
    sta var_7
 :  lda var_7
    sta (address_2), y                     ; store new y pos

    pla
    tay

    ; if outside of screen stop the projectile by setting the direction to zero
    cpx #$01
    bcc :+
    dey
    lda var_9
    clc
    eor #$ff
    adc #$01
    sta (address_1), Y                      ; overwrite yDir
    dey
    lda #$00
    sta (address_1), Y                      ; overwrite xDir
    iny
    iny

:   dec var_1
    jmp @update_mov_comp
.endproc


; var_7                 : new value
; var_8                 : old value
; var_9                 : dif
; var_10                : result
check_for_overflow:
    lda var_9
    bmi @check_negative_val

    lda var_7                               ; new value is bigger then old value -> carry set .. return
    cmp var_8
    bcs @return
    inx

@check_negative_val:
    lda var_8   ; direction is negative .. old value needs to be bigger than new value
    cmp var_7  ;var_8
    bcs @return
    inx
@return:
    rts
