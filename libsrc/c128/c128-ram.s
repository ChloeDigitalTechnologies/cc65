;
; Extended memory driver for the C128 RAM in bank #1
;
; Ullrich von Bassewitz, 2002-12-04
;

	.include  	"zeropage.inc"

      	.include  	"em-kernel.inc"
        .include        "em-error.inc"
        .include        "c128.inc"


        .macpack        generic


; ------------------------------------------------------------------------
; Header. Includes jump table

.segment        "JUMPTABLE"

; Driver signature

        .byte   $65, $6d, $64           ; "emd"
        .byte   $00                     ; EM API version number

; Jump table.

        .word   INSTALL
        .word   DEINSTALL
        .word   PAGECOUNT
        .word   MAP
        .word   USE
        .word   COMMIT
	.word	COPYFROM
        .word   COPYTO

; ------------------------------------------------------------------------
; Constants

BASE	= $400
TOPMEM  = $FF00
PAGES  	= (TOPMEM - BASE) / 256

; ------------------------------------------------------------------------
; Data.

.data
curpage:        .word   $FFFF           ; Current page number (invalid)

.bss
window:         .res    256             ; Memory "window"

.code

; ------------------------------------------------------------------------
; INSTALL routine. Is called after the driver is loaded into memory. If
; possible, check if the hardware is present and determine the amount of
; memory available.
; Must return an EM_ERR_xx code in a/x.
;

INSTALL:
        lda     #<EM_ERR_OK
        ldx     #>EM_ERR_OK
        rts

; ------------------------------------------------------------------------
; DEINSTALL routine. Is called before the driver is removed from memory.
; Can do cleanup or whatever. Must not return anything.
;

DEINSTALL:
        rts


; ------------------------------------------------------------------------
; PAGECOUNT: Return the total number of available pages in a/x.
;

PAGECOUNT:
        lda     #<PAGES
        ldx     #>PAGES
        rts

; ------------------------------------------------------------------------
; MAP: Map the page in a/x into memory and return a pointer to the page in
; a/x. The contents of the currently mapped page (if any) may be discarded
; by the driver.
;

MAP:    sta     curpage
        stx     curpage+1               ; Remember the new page

        clc
        adc	#>BASE
        sta	ptr1+1
        ldy	#$00
        sty    	ptr1

        lda     #<ptr1
        sta     FETVEC

; Transfer one page

@L1:    ldx     #MMU_CFG_RAM1
        jsr     FETCH
        sta     window,y
        iny
        bne     @L1

; Return the memory window

        lda     #<window
        ldx     #>window                ; Return the window address
        rts

; ------------------------------------------------------------------------
; USE: Tell the driver that the window is now associated with a given page.

USE:    sta     curpage
        stx     curpage+1               ; Remember the page
        lda     #<window
        ldx     #>window                ; Return the window
        rts

; ------------------------------------------------------------------------
; COMMIT: Commit changes in the memory window to extended storage.

COMMIT: lda     curpage			; Get the current page
        ldx     curpage+1
        bmi     done                    ; Jump if no page mapped

        clc
        adc	#>BASE
        sta	ptr1+1
        ldy	#$00
        sty    	ptr1

        lda     #<ptr1
        sta     STAVEC

; Transfer one page. Y must be zero on entry

@L1:    lda     window,y
        ldx     #MMU_CFG_RAM1
        jsr     STASH
        iny
        bne     @L1

; Done

done:   rts

; ------------------------------------------------------------------------
; COPYFROM: Copy from extended into linear memory. A pointer to a structure
; describing the request is passed in a/x.
; The function must not return anything.
;

COPYFROM:
        sta     ptr3
        stx     ptr3+1                  ; Save the passed em_copy pointer

        ldy     #EM_COPY_OFFS
        lda     (ptr3),y
        sta     ptr1
        ldy     #EM_COPY_PAGE
        lda     (ptr3),y
        clc
        adc     #>BASE
        sta     ptr1+1                  ; From

        ldy     #EM_COPY_BUF
        lda     (ptr3),y
        sta     ptr2
        iny
        lda     (ptr3),y
        sta     ptr2+1                  ; To

        lda     #<ptr1
        sta     FETVEC

        ldy     #EM_COPY_COUNT+1
        lda     (ptr3),y                ; Get number of pages
        beq     @L2                     ; Skip if no full pages
        sta     tmp1

; Copy full pages

        ldy     #$00
@L1:    ldx     #MMU_CFG_RAM1
        jsr     FETCH
        sta     (ptr2),y
        iny
        bne     @L1
        inc     ptr1+1
        inc     ptr2+1
        dec     tmp1
        bne     @L1

; Copy the remainder of the page

@L2:    ldy     #EM_COPY_COUNT
        lda     (ptr3),y                ; Get bytes in last page
        beq     @L4
        sta     tmp1

        ldy     #$00
@L3:    ldx     #MMU_CFG_RAM1
        jsr     FETCH
        sta	(ptr2),y
        iny
        dec     tmp1
        bne     @L3

; Done

@L4:    rts

; ------------------------------------------------------------------------
; COPYTO: Copy from linear into extended memory. A pointer to a structure
; describing the request is passed in a/x.
; The function must not return anything.
;

COPYTO: sta     ptr3
        stx     ptr3+1                  ; Save the passed em_copy pointer

        ldy     #EM_COPY_OFFS
        lda     (ptr3),y
        sta     ptr1
        ldy     #EM_COPY_PAGE
        lda     (ptr3),y
        clc
        adc     #>BASE
        sta     ptr1+1                  ; To

        ldy     #EM_COPY_BUF
        lda     (ptr3),y
        sta     ptr2
        iny
        lda     (ptr3),y
        sta     ptr2+1                  ; From

        lda     #<ptr1
        sta     STAVEC

        ldy     #EM_COPY_COUNT+1
        lda     (ptr3),y                ; Get number of pages
        beq     @L2                     ; Skip if no full pages
        sta     tmp1

; Copy full pages

        ldy     #$00
@L1:    lda     (ptr2),y
        ldx     #MMU_CFG_RAM1
        jsr     STASH
        iny
        bne     @L1
        inc     ptr1+1
        inc     ptr2+1
        dec     tmp1
        bne     @L1

; Copy the remainder of the page

@L2:    ldy     #EM_COPY_COUNT
        lda     (ptr3),y                ; Get bytes in last page
        beq     @L4
        sta     tmp1
                    
        ldy     #$00
@L3:    lda     (ptr2),y
        ldx     #MMU_CFG_RAM1
        jsr     STASH
        iny
        dec     tmp1
        bne     @L3

; Done

@L4:    rts

