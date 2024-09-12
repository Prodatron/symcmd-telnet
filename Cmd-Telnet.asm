;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                           SymbOS network daemon                            @
;@                                S Y M T E L                                 @
;@                                                                            @
;@                   (c) 2007-2015 by Prodatron / SymbiosiS                   @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;todo
;- terminal selection


;--- MAIN ---------------------------------------------------------------------
;### PRGPRZ -> Programm-Prozess
;### PRGEND -> Programm beenden

;--- CONFIG-ROUTINES ----------------------------------------------------------
;### CFGPAR -> Extract config data from command line parameter
;### CFGUPD -> Updates setting texts with current configuration
;### CFGSET -> User changes the current configuration


;==============================================================================
;### CODE AREA ################################################################
;==============================================================================

;### PRGPRZ -> Programm-Prozess
prgparanz   dw 0

prgprz  call SyShell_PARALL ;get command line parameter
        ld (prgparanz),de
        call SyShell_PARSHL

        ld a,(SyShell_Vers)
        cp 20
        jp c,prgendv
        call cfgpar         ;extract config data from command line parameter

        ld hl,txttit        ;** print title message
        call SyShell_STROUT0
        call SyNet_NETINI           ;init network API
        ld hl,txterr2
        jp c,prgend0

        ld hl,(prgparanz)
        dec l
        ld a,l
        or h
        ld hl,txttit1
        call z,SyShell_STROUT0

prgprz1 call cfgupd         ;** print current configuration
        ld hl,cfgadr
        dec (hl)
        jr z,prgprz3        ;host address has been passed via command line -> connect at once
        inc (hl)
        ld hl,txtcfgd
        call SyShell_STROUT0
        ld hl,msgstr
        call SyShell_STRINP0    ;get IP/domain or empty input (=user wants to change config)
        jp c,prgend         ;error -> end
        jp nz,prgend        ;eof   -> end
        ld hl,msgstr
        call clclen
        dec c
        jr z,prgprz2
        inc c
        jr nz,prgprz3
        call cfgset         ;** change configuration
        jr prgprz1
prgprz2 call cfgsetx
        jr prgprz1
prgprz3 call netcon         ;** connection
        jr c,prgprz1
        ld d,3
        call SyShell_CHROUT0
        ld hl,msgstr
        inc h
        ld (trmoutpnt),hl
        ld a,(cfglfd)
        cpl
        add 3
        ld (trmputtab+1),a
        call logopn
        call netses
        push af
        call logclo
        pop af
        ld hl,txtcon3
        jr nc,prgprz4
        ld hl,txtcon4
prgprz4 call SyShell_STROUT0
        jr prgprz1

;### PRGEND -> Programm beenden
prgendv ld hl,txterr5
prgend0 call SyShell_STROUT0
prgend  ld e,0
        call SyShell_EXIT       ;tell Shell, that process will quit
        ld hl,(App_BegCode+prgpstnum)
        call SySystem_PRGEND    ;end own application
prgend1 rst #30                 ;wait until end
        jr prgend1


;==============================================================================
;### LOGGING-ROUTINES #########################################################
;==============================================================================

logfil  ds 256
loghnd  db 0

;### LOGOPN -> Creates new logfile
logopn  ld a,-1
        ld (loghnd),a
        ld a,(cfglog)
        or a
        ret z
        ld de,0
        ld hl,cfglfn
        ld bc,logfil
        push bc
        call SyShell_PTHADD
        pop hl
        ld a,(App_BnkNum)
        db #dd:ld h,a
        xor a
        call SyFile_FILNEW
        ret c
        ld (loghnd),a
        ret

;### LOGWRT -> Writes into logfile
;### Input      (trmoutpnt)=Address, BC=length
logwrt  ld a,(loghnd)
        inc a
        ret z
        dec a
        ld hl,(trmoutpnt)
        ld de,(App_BnkNum)
        jp SyFile_FILOUT

;### LOGCLO -> Closes logfile
logclo  ld a,(loghnd)
        inc a
        ret z
        dec a
        jp SyFile_FILCLO


;==============================================================================
;### CONFIG -ROUTINEN #########################################################
;==============================================================================

cfgadr  db 0    ;flag, if address has been passed via command line
cfgprt  dw 23   ;port number
cfgter  db 0,0  ;0=ansi, 1=vt100, 2=vt52
cfglfd  db 0,0  ;0=CR+LF, 1=CR
cfgech  db 0,0  ;0=echo off, 1=echo on
cfglog  db 0    ;0=logfile off, 1=logfile on
cfglfn  ds 256  ;logfile name

;### CFGPAR -> Extract config data from command line parameter
cfgpart db "port=":dw 1,65534,cfgprt
        db "term=":dw 0,3,    cfgter
        db "cr=  ":dw 0,1,    cfglfd
        db "echo=":dw 0,1,    cfgech
        db "log= ":dw 0,0

cfgpar  ld a,(prgparanz+1)
        or a
        jr z,cfgpar1
        ld hl,(SyShell_CmdParas)
        ld bc,256
        ld de,msgstr
        ldir
        ld a,1
        ld (cfgadr),a
cfgpar1 ld a,(prgparanz+0)
        ld ix,SyShell_CmdSwtch
cfgpar2 sub 1               ;command line parameter loop
        ret c
        push af
        ld e,(ix+0)
        ld d,(ix+1)
        ld hl,cfgpart
        ld b,5
        ld a,(de)           ;test, if help
        call clclcs
        cp "h"
        jr nz,cfgpar3
        ld a,(ix+2)
        cp 1
        jr nz,cfgpar3
        ld hl,txthlp1
        call SyShell_STROUT0
        ld hl,txthlp2
        call SyShell_STROUT0
        jp prgend
cfgpar3 push de             ;parameter type loop
        push hl
cfgpar4 ld a,(de)           ;char loop
        call clclcs
        cp (hl)
        jr nz,cfgpar5
        inc de
        inc hl
        cp "="
        jr nz,cfgpar4
        jr cfgpar7
cfgpar5 pop hl              ;not identical -> try next type
        ld de,11
        add hl,de
        pop de
        djnz cfgpar3
cfgpar6 pop af              ;next command line parameter
        ld bc,3
        add ix,bc
        jr cfgpar2
cfgpar7 pop iy              ;parameter found
        push de
        ex (sp),ix
        ld e,(iy+7)
        ld d,(iy+8)
        ld a,e
        or d
        jr z,cfgpar9
        ld c,(iy+9)         ;check ranges
        ld b,(iy+10)
        push bc
        ld c,(iy+5)
        ld b,(iy+6)
        xor a
        call clcr16
        pop iy
cfgpar8 pop ix
        pop de
        jr c,cfgpar6
        ld (iy+0),l
        ld (iy+1),h
        jr cfgpar6
cfgpar9 push ix             ;copy logfile path
        pop hl
        ld de,cfglfn
        ld bc,256
        ldir
        xor a
        inc a
        ld (cfglog),a
        jr cfgpar8

;### CFGUPD -> Updates setting texts with current configuration
cfgupd  ld c,5-1            ;port
        ld hl,txtcfg1
        call cfgupd1
        ld de,0
        ld ix,(cfgprt)
        ld iy,txtcfg1
        call clcn32
        ld (iy+1),32
        ld a,(cfgter)       ;terminal
        ld hl,txtcfga
        ld de,txtcfg2
        call cfgupd2
        ld a,(cfglfd)       ;linefeed
        ld hl,txtcfgb
        ld de,txtcfg3
        call cfgupd2
        ld a,(cfgech)       ;echo
        ld hl,txtcfgc
        ld de,txtcfg4
        call cfgupd2
        ld hl,txtcfg5       ;logfile
        ld c,12-1
        call cfgupd1
        ld a,(cfglog)
        or a
        jr nz,cfgupd3
        ld hl,txtcfgc       ;logfile -> no
        ld de,txtcfg5
        call cfgupd2
        jr cfgupd9
cfgupd3 ld hl,cfglfn        ;logfile -> yes, print name without optional path
        ld b,0
cfgupd6 ld e,l
        ld d,h
cfgupd7 dec b
        jr z,cfgupd8
        ld a,(hl)
        inc hl
        cp "/"
        jr z,cfgupd6
        cp "\"
        jr z,cfgupd6
        or a
        jr nz,cfgupd7
cfgupd8 ex de,hl
        ld de,txtcfg5
        ld bc,12*256+255
cfgupd4 ld a,(hl)
        ldi
        dec b
        jr z,cfgupd5
        or a
        jr nz,cfgupd4
cfgupd5 ld a,32
        dec de
        ld (de),a
cfgupd9 ld hl,txtcfg
        call SyShell_STROUT0
        ret
cfgupd1 ld e,l              ;** writes C+1 spaces to (HL)
        ld d,h
        inc de
        ld (hl),32
        ld b,0
        ldir
        ret
cfgupd2 ld c,a              ;** HL=option texte, A=index (0-x), DE=destination
        add a
        add a
        add c
        ld c,a
        ld b,0
        add hl,bc
        ld c,5
        ldir
        ret

;### CFGSET -> User changes the current configuration
cfgsetx ld a,(msgstr)   ;** user entered letter directly
        call clclcs
        cp "p":jp z,cfgse1p
        cp "t":jp z,cfgse1t
        cp "f":jp z,cfgse1f
        cp "e":jp z,cfgse1e
        cp "l":jr z,cfgse1l
        ret

cfgset  ld hl,txtchg    ;** user has to press the letter after hitting return
        call SyShell_STROUT0
cfgset1 call SyShell_CHRINP0
        jp nz,cfgset4
        cp 13
        jp z,cfgset4
        call clclcs
        cp "p":jr z,cfgsetp
        cp "t":jp z,cfgsett
        cp "f":jp z,cfgsetf
        cp "e":jp z,cfgsete
        cp "l"
        jr nz,cfgset1
        call cfgset0    ;** logfile
cfgse1l ld hl,txtchg3
        call SyShell_STROUT0
        ld hl,msgstr
        call SyShell_STRINP0    ;get logfile or empty input (=no logfile)
        ret nz          ;eof -> don't change
        ld hl,msgstr
        call clclen
        xor a
        cp c
        jr nz,cfgset2
        ld (cfglog),a   ;no log
        ret
cfgset2 inc a
        ld (cfglog),a   ;log -> copy path/file
        ld hl,msgstr
        ld de,cfglfn
        ld bc,256
        ldir
        ret
cfgsetp call cfgset0    ;** port
cfgse1p ld hl,txtchg1
        call SyShell_STROUT0
        ld hl,msgstr
        call SyShell_STRINP0     ;get port number
        ret nz          ;eof -> don't change
        ld hl,msgstr
        call clclen
        inc c:dec c
        ret z           ;empty -> don't change
        ld ix,msgstr
        xor a
        ld bc,1
        ld de,65534
        call clcr16
        jr nc,cfgset3
        ld hl,txtchg5
        call SyShell_STROUT0
        ret
cfgset3 ld (cfgprt),hl
        ret
cfgsett call cfgset0    ;** terminal
cfgse1t ld hl,txtchg2
        call SyShell_STROUT0
cfgset6 call SyShell_CHRINP0
        jr nz,cfgset4
        cp 13
        jr z,cfgset4
        call clclcs
        ld c,0:cp "a":jr z,cfgset5
        ld c,1:cp "1":jr z,cfgset5
        ld c,2:cp "5":jr z,cfgset5
        ld c,3:cp "v":jr nz,cfgset6
cfgset5 ld b,a
        ld a,c
        ld (cfgter),a
        ld a,b
        jr cfgset0
cfgsetf call cfgset0    ;** linefeed
cfgse1f ld hl,cfglfd
        ld a,(hl)
        xor 1
        ld (hl),a
        ret
cfgsete call cfgset0    ;** echo
cfgse1e ld hl,cfgech
        ld a,(hl)
        xor 1
        ld (hl),a
        ret
cfgset0 ld d,a          ;plot selected letter
        call SyShell_CHROUT0
cfgset4 ld hl,txtchg4
        call SyShell_STROUT0
        ret


;==============================================================================
;### NETWORK-ROUTINES #########################################################
;==============================================================================

netsid  db 0    ;socket ID

;### NETCON -> open connection
;### Output     CF=0 -> connection opened successfully, CF=1 -> attempt failed
netcont db 0    ;timeout

netcon  ld hl,txtcon        ;print connection attempt
        call SyShell_STROUT0
        ld hl,msgstr
        call SyShell_STROUT0
        ld hl,txtcfg1
        ld de,txtcon2
        ld bc,5
        ldir
        ld hl,txtcon1
        call SyShell_STROUT0

        ld hl,msgstr        ;DNS resolve
        call SyNet_DNSRSV   ;ix,iy=IP
        ld hl,txterr3
        jr c,netcon0

        push ix
        push iy
        ld hl,txtcon5a
        ld e,"."
        db #dd:ld a,l:call clcn08:ld (hl),e:inc hl
        db #dd:ld a,h:call clcn08:ld (hl),e:inc hl
        db #fd:ld a,l:call clcn08:ld (hl),e:inc hl
        db #fd:ld a,h:call clcn08:ld (hl),0
        ld hl,txtcon5 :call SyShell_STROUT0
        ld hl,txtcon5b:call SyShell_STROUT0
        pop iy
        pop ix

        ld hl,-1            ;HL=local port (random)
        ld de,(cfgprt)      ;DE=remote port
        xor a               ;A=client mode
        call SyNet_TCPOPN   ;open tcp connection
        ld hl,txterr6
        jr c,netcon0
        ld (netsid),a
if 0
        xor a
        ld (netcont),a
netcon2 rst #30                     ;wait until established ##!!## DATA RECEIVED SKIP
        call SyNet_NETEVT
        jr nc,netcon4
        ld hl,netcont
        dec (hl)
        jr nz,netcon2
        ld hl,txterr4
        jr netcon1
netcon4 ld a,l
        and 127
        cp 2
        jr c,netcon2
        ld hl,txterr4
        jr nz,netcon0
endif
        ld hl,txtcon0               ;connection established
        call SyShell_STROUT0
        or a
        ret

netcon1 push hl
        ld a,(netsid)
        call SyNet_TCPCLO
        pop hl
netcon0 push hl                     ;error -> print message
        ld hl,txterr
        call SyShell_STROUT0
        pop hl
        call SyShell_STROUT0
        scf
        ret


;### NETSES -> Does a Telnet session
;### Output     CF=0 client closed, CF=1 server closed
netses  ld c,MSC_SHL_CHRINP     ;tell SymShell, that we want a new char from the console
        ld a,(SyShell_PrcID)
        ld d,0
        call msgsnd
netses0 ld a,(App_PrcID)        ;sleep while waiting for a message
        db #dd:ld l,a
        db #dd:ld h,-1
        ld iy,App_MsgBuf
        rst #08
        db #dd:dec l
        jr nz,netses0
        ld a,(SyShell_PrcID)    ;message from shell?
        db #dd:cp h
        jr z,netses2
        ld a,(SyNet_PrcID)      ;message from network daemon?
        db #dd:cp h
        jr nz,netses0

        call snwmsgo_afbchl
        ld a,l                  ;A=status (0=in process, 2=established, 3=close_wait, 4=close, 128=data received)
        bit 7,a
        jr nz,netses1
        cp 3
        jr c,netses0
        jr netses3
netses1 inc b:dec b             ;data received
        jr z,netses4
        ld bc,255
netses4 ld a,(netsid)
        ld de,(App_BnkNum)
        ld hl,(trmoutpnt)
        call SyNet_TCPRCV
        push hl
        ld a,c
        or b
        push af
        push bc
        call nz,logwrt
        pop bc
        pop af
        call nz,trmout
        pop bc
        ld a,c
        or b
        jr nz,netses1
        jr netses0

netses2 ld a,(App_MsgBuf+0)
        or a
        jp z,prgend             ;SymShell wants us to quit -> bye bye
        cp MSR_SHL_CHRINP
        jr nz,netses0           ;wrong message -> repeat loop
        ld a,(App_MsgBuf+3)
        or a
        jp nz,prgend
        ld a,(App_MsgBuf+1)
        or a
        ld a,3
        jr nz,netses5           ;Ctrl+C -> translate to byte3
        ld a,(App_MsgBuf+2)
        cp 168
        jr z,netses3
netses5 call trmput             ;convert char
        ld a,c
        or b
        jp z,netses
        ld a,(netsid)
        ld de,(App_BnkNum)
        ld hl,msgstr
        push bc
        call netsnd
        pop bc
        jr c,netses3

        ld a,(cfgech)           ;** echo
        or a
        jp z,netses
        ld de,(trmoutpnt)
        ld hl,msgstr
        push bc
        ldir
        pop bc
        call trmout
        jp netses

netses3 push af                 ;** disconnect
        ld a,(netsid)
        push af
        call SyNet_TCPDIS
        pop af
        call SyNet_TCPCLO
        pop af
        ret

;### NETSND -> sends data to a TCP connection
;### Input      A=handle, HL=address, E=bank, BC=length
;### Output     CF=0 ok, CF=1 connection closed (BC=remaining length)
;### Destroyed  ??
netsnd  push de
        push hl
        call SyNet_TCPSND   ;-> BC=bytes sent, HL=bytes remaining
        jr c,netsnd1
        jr z,netsnd1
        ex de,hl
        pop hl
        add hl,bc
        ld c,e
        ld b,d
        pop de
        jr netsnd
netsnd1 pop de
        pop de
        ret


;==============================================================================
;### TERMINAL-ROUTINES ########################################################
;==============================================================================

;### TRMOUT -> Converts and prints text
;### Input      (msgstr+256)=all text, (trmoutpnt)=address of new text, BC=length of new text
;### Output     (trmoutpnt)=address after remaining textcode

trmoutpnt   dw 0    ;destination address for new data

trmout  ld hl,(trmoutpnt)
        add hl,bc
        ld de,msgstr
        inc d           ;de=data beg
        sbc hl,de
        ld c,l
        ld b,h          ;bc=length
        ex de,hl        ;hl=source
        ld de,msgstr    ;de=destination
trmout1 ld a,(hl)
        cp 255
        jr z,trmouta
        cp 32
        jr c,trmout4
        cp 128
        jr nc,trmout3
trmout2 ldi             ;printable char -> just copy it
        jp pe,trmout1
        jr trmout7
trmout3 ld (hl),127     ;char >127 -> use 127
        jr trmout2
trmout4 cp 27           ;27 -> convert escape code
        jr z,trmout9
        cp 8            ;char <32 -> only accept 8-13
        jr c,trmout5
        cp 13+1
        jr c,trmout2
trmout5 inc hl
        dec bc
trmout6 ld a,c
        or b
        jr nz,trmout1
trmout7 ld hl,msgstr    ;** done without remaining code
        inc h
trmout8 ld (trmoutpnt),hl
        ex de,hl
        ld (hl),0
        ld hl,msgstr
        call SyShell_STROUT0
        ;...
        ret
trmout9 call trmcod
        jr nc,trmout6
        push de
        ld de,msgstr
        inc d
        ldir
        ex de,hl
        pop de
        jr trmout8

trmouta ld a,(netsid)           ;##!!## currently more a dummy
        ld de,(App_BnkNum)
        ld hl,trmoutcmd
        ld bc,trmoutcmd0-trmoutcmd
        call netsnd
        ld de,msgstr
        jr trmout7

trmoutcmd   db 255,252,24
            db 255,252,32
            db 255,252,3
            db 255,252,1
            db 255,252,5
            db 255,252,33
trmoutcmd0

;### TRMCOD -> Converts Escape-Code
;### Input      HL=source (starts with 27), DE=destination, BC=remaining length
;### Output     CF=0 -> ok, HL,DE,BC updated
;###            CF=1 -> code-end not present, HL,DE,BC=unchanged
trmcodp ds 2*2

trmcod  ld ix,-1
        ld (trmcodp+0),ix
        ld (trmcodp+2),ix
        push hl
        push de
        push bc
        call trmcod0
        cp "["
        jr z,trmcod4
        ld ix,trmanstab0    ;** code without parameters
trmcod1 inc (ix+2)
        dec (ix+2)
        jr z,trmcod3
        cp (ix+2)
        jr z,trmcod2
        inc ix
        inc ix
        inc ix
        jr trmcod1
trmcod2 push hl
        ld l,(ix+0)
        ld h,(ix+1)
        ex (sp),hl
        ret
trmcod3 pop ix              ;** end
        pop ix
        pop ix
        inc hl
        dec bc
        or a
        ret
trmcod4 ld ix,trmcodp       ;** code with parameters
        db #fd:ld l,2
trmcod5 call trmcod0
        cp 34
        jr nz,trmcode
trmcodf call trmcod0    ;skip strings
        cp 34
        jr nz,trmcodf
        call trmcod0
        jr trmcodg
trmcode ld (trmcod8+1),de
        ld de,-1
        cp ";"
        jr z,trmcod7
        cp "0"
        jr c,trmcod7
        cp "9"+1
        jr nc,trmcod7
        ld de,0         ;get numeric parameter
trmcod6 ex de,hl
        push bc
        add hl,hl
        ld c,l
        ld b,h
        add hl,hl
        add hl,hl
        add hl,bc
        sub "0"
        ld c,a
        ld b,0
        add hl,bc
        pop bc
        ex de,hl
        call trmcod0
        cp "0"
        jr c,trmcod7
        cp "9"+1
        jr c,trmcod6
trmcod7 db #fd:inc l
        db #fd:dec l
        jr z,trmcod8
        ld (ix+0),e     ;only add, if number of parameters <=2
        ld (ix+1),d
        db #fd:dec l
        inc ix
        inc ix
trmcod8 ld de,0
trmcodg cp ";"
        jr nz,trmcod9
        jr trmcod5
trmcod9 ld ix,trmanstab1    ;search code
trmcoda inc (ix+2)
        dec (ix+2)
        jr z,trmcod3
        cp (ix+2)
        jr z,trmcodb
        push bc
        ld bc,7
        add ix,bc
        pop bc
        jr trmcoda
trmcodb push hl
        ld l,(ix+0)
        ld h,(ix+1)
        ex (sp),hl
        push hl
        ld hl,(trmcodp+2)
        ld a,l
        and h
        inc a
        jr nz,trmcodc
        ld l,(ix+5)
        ld h,(ix+6)
trmcodc push hl:pop iy      ;iy=param2
        ld hl,(trmcodp+0)
        ld a,l
        and h
        inc a
        jr nz,trmcodd
        ld l,(ix+3)
        ld h,(ix+4)
trmcodd push hl:pop ix      ;ix=param1
        pop hl
        ret
trmcod0 inc hl          ;-> A=next byte
        dec bc
        ld a,c
        or b
        ld a,(hl)
        ret nz
        pop hl
        pop bc
        pop de
        pop hl
        scf
        ret

trmanstab0  ;no parameters
;### VT100
dw trmvt1sk1:db "("         ;ignore, skip one more byte
dw trmvt1sk1:db ")"
dw trmvt1sk1:db "#"
dw trmvt1rup:db "D"         ;scroll screen up one line
dw trmvt1rdw:db "M"         ;scroll screen down one line
dw trmvt1clf:db "E"         ;move to next line
dw trmanscpu:db "7"         ;cursor save
dw trmanscpo:db "8"         ;cursor restore
dw trmvt1tst:db "H"         ;set tab
ds 3
;### VT52
dw trmvt5cu1:db "A"         ;cursor up
dw trmvt5cd1:db "B"         ;cursor down
dw trmvt5cr1:db "C"         ;cursor right
dw trmvt5cl1:db "D"         ;cursor left
dw trmvt5c00:db "H"         ;cursor 0/0
dw trmvt5clr:db "I"         ;reverse line feed
dw trmvt5eel:db "K"         ;erase end of line
dw trmvt5ees:db "J"         ;erase end of screen
;                           ;missing -> EscLineColumn * Move cursor to v,h location
ds 3

trmanstab1  ;including parameters
;### VT100
dw trmvt1tcl:db "g":dw 0,0  ;clear tab(s)
;### ANSI
dw trmanscps:db "H":dw 0,0  ;cursor position
dw trmanscps:db "f":dw 0,0
dw trmanscup:db "A":dw 1,0  ;cursor up
dw trmanscdw:db "B":dw 1,0  ;cursor down
dw trmanscrg:db "C":dw 1,0  ;cursor right
dw trmansclf:db "D":dw 1,0  ;cursor left
dw trmanscpu:db "s":dw 0,0  ;cursor save
dw trmanscpo:db "u":dw 0,0  ;cursor restore
;### ANSI/VT100
dw trmansesc:db "J":dw 0,0  ;erase screen (0/default=down, 1=up, 2=entire)
dw trmanseln:db "K":dw 0,0  ;erase line (0/default=right, 1=left, 2=entire)
ds 3

;### ANSI specific
trmanscps                               ;cursor position
        ld a,31
        ld (de),a:inc de
        db #fd:ld a,l
        ld (de),a:inc de
        db #dd:ld a,l
        jr trmans0
trmanscup ld iy,256*185+25:jr trmans1   ;cursor up
        jr trmans1
trmanscdw ld iy,256*160+25:jr trmans1   ;cursor down
        jr trmans1
trmansclf ld iy,256*080+80:jr trmans1   ;cursor left
        jr trmans1
trmanscrg ld iy,256*000+80              ;cursor right
trmans1 db #fd:ld a,l
        db #dd:inc h
        db #dd:dec h
        jr nz,trmans2
        db #dd:cp l
        jr c,trmans4
        db #dd:ld a,l
trmans4 or a
        jp z,trmcod3
trmans2 db #fd:add h
        db #dd:ld l,a
        ld a,14
trmans3 ld (de),a
        inc de
        db #dd:ld a,l
trmans0 ld (de),a:inc de
        jp trmcod3
trmanscpu ld a,4:jr trmans0             ;cursor save
trmanscpo ld a,5:jr trmans0             ;cursor restore
trmansesc                               ;erase screen
        db #dd:ld a,l
        cp 1
        ld a,20         ;0=down
        jr c,trmans0
        ld a,19         ;1=up
        jr z,trmans0
        ld a,12         ;2=entire
        jr trmans0
trmanseln                               ;erase line
        db #dd:ld a,l
        cp 1
        ld a,18         ;0=right
        jr c,trmans0
        ld a,17         ;1=up
        jr z,trmans0
        ld (de),a       ;2=entire
        inc de
        ld a,18
        jr trmans0

;### VT100 specific
trmvt1sk1 call trmcod0:jp trmcod3       ;ignore, skip one more byte
trmvt1rup db #dd:ld l,1                 ;scroll screen up one line
trmvt11 ld a,29
        jr trmans3
trmvt1rdw db #dd:ld l,2                 ;scroll screen down one line
        jr trmvt11
trmvt1clf ld a,13                       ;move to next line
        db #dd:ld l,10
        jr trmans3
trmvt1tst ld a,22:jr trmans0            ;set tab
trmvt1tcl db #dd:ld a,l                 ;clear tab(s)
        or a
        ld a,23
        jr z,trmans0
        db #dd:ld a,l
        cp 3
        ld a,24
        jr z,trmans0
        jp trmcod3

;### VT52 specific
trmvt5cu1 ld a,11:jr trmans0            ;cursor up
trmvt5cd1 ld a,10:jr trmans0            ;cursor down
trmvt5cl1 ld a,08:jr trmans0            ;cursor left
trmvt5cr1 ld a,09:jr trmans0            ;cursor right
trmvt5c00 ld a,30:jr trmans0            ;cursor 0/0
trmvt5clr ld a,13                       ;reverse line feed
        db #dd:ld l,11
        jr trmans3
trmvt5eel ld a,18:jp trmans0            ;erase end of line
trmvt5ees ld a,20:jp trmans0            ;erase end of screen


;### TRMPUT -> Converts char into terminal code
;### Input      A=char
;### Output     (msgstr)=code, BC=length
trmputtab   db 13,  2,13,10,0   ;CR
            db 136, 3,27,"[A"   ;up
            db 137, 3,27,"[B"   ;down
            db 138, 3,27,"[D"   ;left
            db 139, 3,27,"[C"   ;right
trmputlen   equ 5

trmput  cp 32
        jr c,trmput2
        cp 128
        jr c,trmput1
        cp 136
        jr c,trmput0
        cp 188
        jr c,trmput2
trmput0 ld bc,0
        ret
trmput1 ld (msgstr),a
        ld bc,1
        ret
trmput2 ld hl,trmputtab
        ld b,trmputlen
        ld de,5
trmput3 inc (hl)
        dec (hl)
        jr z,trmput1
        cp (hl)
        jr z,trmput4
        add hl,de
        djnz trmput3
        jr trmput1
trmput4 inc hl
        ld a,(hl)
        inc hl
        ld c,a
        ld b,d
        ld de,msgstr
        ldir
        ld c,a
        ret


;==============================================================================
;### SUB-ROUTINES #############################################################
;==============================================================================

;### MSGGET -> Message für Programm abholen
;### Ausgabe    CF=0 -> keine Message vorhanden, CF=1 -> IXH=Absender, (App_MsgBuf)=Message, A=(App_MsgBuf+0), IY=App_MsgBuf
;### Veraendert 
msgget  ld a,(App_PrcID)
        db #dd:ld l,a           ;IXL=Rechner-Prozeß-Nummer
        db #dd:ld h,-1
        ld iy,App_MsgBuf        ;IY=Messagebuffer
        rst #08                 ;Message holen -> IXL=Status, IXH=Absender-Prozeß
        or a
        db #dd:dec l
        ret nz
        ld iy,App_MsgBuf
        ld a,(iy+0)
        or a
        jp z,prgend
        scf
        ret

;### MSGSND -> Message an Prozess senden
;### Eingabe    A=Prozess, C=Kommando, D=Kanal, E=Bank/Zeichen, HL=Adresse (, B=Länge)
msgsnd  db #dd:ld h,a
        ld a,(App_PrcID)
        db #dd:ld l,a
        ld iy,App_MsgBuf
        ld (iy+0),c
        ld (iy+1),d
        ld (iy+2),e
        ld (iy+3),l
        ld (iy+4),h
        ld (iy+5),b
        rst #10
        ret

;### CLCLEN -> Ermittelt Länge eines Strings
;### Eingabe    HL=String
;### Ausgabe    HL=Stringende (0), BC=Länge (maximal 255)
;### Verändert  -
clclen  push af
        xor a
        ld bc,255
        cpir
        ld a,254
        sub c
        ld c,a
        dec hl
        pop af
        ret

;### CLCLCS -> Wandelt Groß- in Kleinbuchstaben um
;### Eingabe    A=Zeichen
;### Ausgabe    A=lcase(Zeichen)
;### Verändert  F
clclcs  cp "A"
        ret c
        cp "Z"+1
        ret nc
        add "a"-"A"
        ret

;### CLCN32 -> Wandelt 32Bit-Zahl in ASCII-String um (mit 0 abgeschlossen)
;### Eingabe    DE,IX=Wert, IY=Adresse
;### Ausgabe    IY=Adresse letztes Zeichen
;### Veraendert AF,BC,DE,HL,IX,IY
clcn32t dw 1,0,     10,0,     100,0,     1000,0,     10000,0
        dw #86a0,1, #4240,#f, #9680,#98, #e100,#5f5, #ca00,#3b9a
clcn32z ds 4

clcn32  ld (clcn32z),ix
        ld (clcn32z+2),de
        ld ix,clcn32t+36
        ld b,9
        ld c,0
clcn321 ld a,"0"
        or a
clcn322 ld e,(ix+0):ld d,(ix+1):ld hl,(clcn32z):  sbc hl,de:ld (clcn32z),hl
        ld e,(ix+2):ld d,(ix+3):ld hl,(clcn32z+2):sbc hl,de:ld (clcn32z+2),hl
        jr c,clcn325
        inc c
        inc a
        jr clcn322
clcn325 ld e,(ix+0):ld d,(ix+1):ld hl,(clcn32z):  add hl,de:ld (clcn32z),hl
        ld e,(ix+2):ld d,(ix+3):ld hl,(clcn32z+2):adc hl,de:ld (clcn32z+2),hl
        ld de,-4
        add ix,de
        inc c
        dec c
        jr z,clcn323
        ld (iy+0),a
        inc iy
clcn323 djnz clcn321
        ld a,(clcn32z)
        add "0"
        ld (iy+0),a
        ld (iy+1),0
        ret

;### CLCR16 -> Wandelt String in 16Bit Zahl um
;### Eingabe    IX=String, A=Terminator, BC=Untergrenze (>=0), DE=Obergrenze (<=65534)
;### Ausgabe    IX=String hinter Terminator, HL=Zahl, CF=1 -> Ungültiges Format (zu groß/klein, falsches Zeichen/Terminator)
;### Veraendert AF,DE,IYL
clcr16  ld hl,0
        db #fd:ld l,a
clcr161 ld a,(ix+0)
        inc ix
        db #fd:cp l
        jr z,clcr163
        sub "0"
        ret c
        cp 10
        ccf
        ret c
        push bc
        add hl,hl:jr c,clcr162
        ld c,l
        ld b,h
        add hl,hl:jr c,clcr162
        add hl,hl:jr c,clcr162
        add hl,bc:jr c,clcr162
        ld c,a
        ld b,0
        add hl,bc:ret c
        pop bc
        jr clcr161
clcr162 pop bc
        ret
clcr163 sbc hl,bc
        ret c
        add hl,bc
        inc de
        sbc hl,de
        ccf
        ret c
        add hl,de
        or a
        ret

;### CLCN08 -> Converts 8bit value into ASCII string (0-terminated)
;### Input      A=Value, HL=Destination
;### Output     HL=points behind last digit
;### Destroyed  AF,BC
clcn08  cp 10
        jr c,clcn082
        cp 100
        jr c,clcn081
        ld c,100
        call clcn083
clcn081 ld c,10
        call clcn083
clcn082 add "0"
        ld (hl),a
        inc hl
        ld (hl),0
        ret
clcn083 ld b,"0"-1
clcn084 sub c
        inc b
        jr nc,clcn084
        add c
        ld (hl),b
        inc hl
        ret


;==============================================================================
;### DATA #####################################################################
;==============================================================================

;### MESSAGES #################################################################

txttit  db 13,10
        db "S Y M T E L   1 . 0               TELNET FOR SYMBOS",13,10
        db "---------------------------------------------------",13,10
        db "written in 2007,2015 by Prodatron      (c)SymbiosiS",13,10,0

txttit1 db 13,10
        db "Type SYMTEL %h for command line parameter help",13,10,0

txthlp1 db 13,10
        db "SymTel 1.0 - Telnet for SymbOS - (c)2015 by SymbiosiS",13,10
        db 13,10
        db "Usage:   SYMTEL [ip or domain] %[option1] ... %[optionN]",13,10
        db 13,10
        db "%port=N - set port number (default=23)",13,10
        db "%term=N - set terminal (0=ANSI, 1=VT100, 2=VT52)",13,10,0
txthlp2 db "%cr=1   - send CR instead of CR+LF, if user hits return",13,10
        db "%echo=1 - switch local echo on",13,10
        db "%log=[file] - activates logging",13,10
        db 13,10
        db "Example: SYMTEL telnet.server.cpc %echo=1 %log=output.txt",13,10
        db 13,10,0

txtcon  db 13,10,"Connecting to ",0
txtcon1 db ", port ":txtcon2:db "#####...",13,10,0
txtcon5 db "DNS resolved ("
txtcon5a db "###.###.###.###",0
txtcon5b db ")",13,10,0
txtcon0 db "Connection established (press ALT+Q to close).",13,10,3,0
txtcon3 db 2,13,10,13,10,"Connection closed.",13,10,0
txtcon4 db "Connection terminated by host.",13,10,0

txterr  db "Error: ",0
txterr2 db "Network daemon not running!",13,10,0
txterr3 db "Host domain look-up failed.",13,10,0
txterr4 db "Couldn't establish connection to host.",13,10,0
txterr5 db "Old shell version. SymTel requires SymShell 2.0 or higher.",13,10,"Please update your SymbOS setup.",13,10,0
txterr6 db "No free socket.",13,10,0

txtcfg  db 2,13,10
        db "Current settings:",13,10
        db "(P)ort     :  ":txtcfg1:db "#####    (E)cho    :  ":txtcfg4:db "off  ",13,10
        db "(T)erminal :  ":txtcfg2:db "ANSI     (L)ogfile :  ":txtcfg5:db "########.### ",13,10
        db "Line(F)eed :  ":txtcfg3:db "CR+LF",13,10,0

txtcfgd db 13,10
        db "Please enter host IP or domain (CTRL+C to quit)",13,10
        db "or press RETURN to change current settings",13,10
        db "SymTEL>",0

txtcfga db "ANSI VT100VT52 "
txtcfgb db "CR+LFCR   "
txtcfgc db "off  on   "

txtchg  db 13,10,"What setting you want to change (P/T/F/E/L): ",3,0
txtchg1 db 2,"New port number: ",0
txtchg2 db 2,"New terminal type (0=ANSI, 1=VT100, 2=VT52): ",3,0
txtchg3 db 2,"Logfile (press RETURN for no logfile): ",0
txtchg4 db 13,10,0
txtchg5 db "Error: Port must be a number between 1 and 65534",0

msgstr  db 0    ;** !!last label!! **


;==============================================================================
;### DATA AREA ################################################################
;==============================================================================

App_BegData

db 0    ;data area must have at least a length of 1 bytes

;==============================================================================
;### TRANSFER AREA ############################################################
;==============================================================================

App_BegTrns
;### PRGPRZS -> stack for application process
        ds 128
prgstk  ds 6*2
        dw prgprz
App_PrcID db 0

;### App_MsgBuf -> message buffer
App_MsgBuf ds 14
