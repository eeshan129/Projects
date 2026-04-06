.model small
.stack 100h

.data
    ; --- THE GRID ---
    grid db 'C','A','T','Q','W','E','R','T'
         db 'L','S','U','N','Y','O','P','A'
         db 'B','A','G','H','I','J','K','L'
         db 'M','N','O','P','Q','R','S','T'
         db 'U','V','W','C','O','A','L','B'
         db 'C','D','C','O','D','E','I','J'
         db 'K','L','M','N','O','P','Q','R'
         db 'S','T','U','V','W','X','Y','Z'

    statusGrid db 64 dup(0)
    curRow db 0
    curCol db 0
    
    inputBuffer db 10 dup('$') 
    inputPos    dw 10 dup(0)   
    bufLen      dw 0

    msgLabel db 'Selection: $'
    msgFound db ' MATCH FOUND!    $'
    msgClear db '                $' 
    msgHelp  db 'ARROWS: Move | SPACE: Select | BACKSPACE: Undo$'
    
    wCat  db 'CAT'
    wSun  db 'SUN'
    wBag  db 'BAG'
    wCoal db 'COAL'
    wCode db 'CODE'
    
    wordsFound db 0
    totalWords equ 5 
    
    msgCongrats db 'CONGRATULATIONS! ALL WORDS FOUND! Play again? (Y/N)$'
    fileName    db 'FOUND.TXT',0
    fileHandle  dw ?
    newline     db 13,10      
    msgNotFound db 'MATCH NOT FOUND!    $'  

.code
main proc
    mov ax, @data
    mov ds, ax
    mov es, ax
    
   ; Open or Create file ONCE at start ---
    mov ah, 3Dh
    mov al, 2 
    lea dx, fileName
    int 21h
    jnc storeHandle
    
    mov ah, 3Ch
    mov cx, 0
    lea dx, fileName
    int 21h
storeHandle:
    mov fileHandle, ax

    call ClearScreen 

main_init: 
    mov wordsFound, 0
    mov curRow, 0
    mov curCol, 0
    call ClearBuffer 

    mov ah, 02h
    mov bh, 0
    mov dh, 12        
    mov dl, 0
    int 10h
    mov dx, offset msgHelp
    mov ah, 09h
    int 21h

    call RedrawFullGrid
    call UpdateBottomText
    call HighlightCell

controlLoop:
    mov ah, 00h
    int 16h           

    cmp al, 27        ; ESC
    je exitGame

    cmp al, 32        ; SPACE
    je handleSelect
    
    cmp al, 08h       ; BACKSPACE
    je handleBackspace

    push ax
    call UnHighlightCell 
    pop ax            

    cmp ah, 48h ; Up
    je goUp
    cmp ah, 50h ; Down
    je goDown
    cmp ah, 4Bh ; Left
    je goLeft
    cmp ah, 4Dh ; Right
    je goRight

    call HighlightCell
    jmp controlLoop

goUp:
    cmp curRow, 0
    je doneMove
    dec curRow
    jmp doneMove
goDown:
    cmp curRow, 7
    je doneMove
    inc curRow
    jmp doneMove
goLeft:
    cmp curCol, 0         
    jg normalLeft         
    cmp curRow, 0         
    je loopToBottom       
    dec curRow            
    mov curCol, 7         
    jmp doneMove
loopToBottom:
    mov curRow, 7         
    mov curCol, 7         
    jmp doneMove
normalLeft:
    dec curCol
    jmp doneMove
goRight:
    cmp curCol, 7         
    jl normalRight        
    cmp curRow, 7         
    je loopToTop          
    inc curRow            
    mov curCol, 0         
    jmp doneMove
loopToTop:
    mov curRow, 0         
    mov curCol, 0         
    jmp doneMove
normalRight:
    inc curCol
    jmp doneMove

doneMove:
    call HighlightCell
    jmp controlLoop

handleBackspace:
    cmp bufLen, 0         
    je controlLoop        
    dec bufLen            
    mov bx, bufLen
    mov inputBuffer[bx], '$' 
    call UpdateBottomText 
    jmp controlLoop

handleSelect:
    call PlayBeep
    call AddCharToBuffer
    call UpdateBottomText
    call ClearMatchLine 

    mov ax, bufLen      
    cmp al, 3           
    je checkWordJmp 
    cmp al, 4
    je checkWordJmp 
    jmp controlLoop 

checkWordJmp: 
    call CheckWord
    jmp controlLoop

exitGame:
    mov bx, fileHandle
    mov ah, 3Eh
    int 21h
    mov ax, 4Ch
    int 21h
main endp

AddCharToBuffer proc
    call GetIndex 
    mov si, ax
    mov al, grid[si]
    mov bx, bufLen
    cmp bx, 5       
    jge resetBuf
    mov inputBuffer[bx], al
    mov inputBuffer[bx+1], '$' 
    shl bx, 1
    mov inputPos[bx], si
    inc bufLen
    ret
resetBuf:
    call ClearBuffer
    ret
AddCharToBuffer endp

CheckWord proc
    cld
    push es
    mov ax, ds
    mov es, ax
    cmp bufLen, 3
    je check3
    cmp bufLen, 4
    je check4
    pop es
    ret
check3:
    lea si, inputBuffer
    lea di, wCat
    mov cx, 3
    repe cmpsb
    je itsAMatch
    lea si, inputBuffer
    lea di, wSun
    mov cx, 3
    repe cmpsb
    je itsAMatch
    lea si, inputBuffer
    lea di, wBag
    mov cx, 3
    repe cmpsb
    je itsAMatch 
    pop es
    ret
check4:
    lea si, inputBuffer
    lea di, wCoal
    mov cx, 4
    repe cmpsb
    je itsAMatch
    lea si, inputBuffer
    lea di, wCode
    mov cx, 4
    repe cmpsb
    je itsAMatch
    call ShowNotFound
    call ClearBuffer
    call UpdateBottomText
    pop es
    ret
itsAMatch:
    pop es
    call SaveWordToFile
    mov cx, bufLen
    mov si, 0
markLoop:
    mov bx, si
    shl bx, 1
    mov di, inputPos[bx]
    mov statusGrid[di], 1
    inc si
    loop markLoop
    mov ah, 02h
    mov bh, 0
    mov dh, 11
    mov dl, 0
    int 10h
    mov dx, offset msgFound
    mov ah, 09h
    int 21h
    call RedrawFullGrid
    call HighlightCell
    call ClearBuffer
    call PlayBeep
    inc wordsFound
    cmp wordsFound, totalWords
    je GameOver
    ret
CheckWord endp

ClearBuffer proc
    mov bufLen, 0
    mov inputBuffer[0], '$'
    ret
ClearBuffer endp

UpdateBottomText proc
    mov ah, 02h
    mov bh, 0
    mov dh, 10
    mov dl, 0
    int 10h
    mov dx, offset msgLabel
    mov ah, 09h
    int 21h
    mov dx, offset inputBuffer
    mov ah, 09h
    int 21h
    mov ah, 02h
    mov dl, ' '
    int 21h
    int 21h
    ret 
UpdateBottomText endp

ClearMatchLine proc
    push ax
    push bx
    push dx
    mov ah, 02h
    mov bh, 0
    mov dh, 11      
    mov dl, 0
    int 10h
    mov dx, offset msgClear 
    mov ah, 09h
    int 21h
    pop dx
    pop bx
    pop ax
    ret
ClearMatchLine endp

ClearScreen proc
    mov ah, 00h
    mov al, 03h 
    int 10h
    ret
ClearScreen endp

GameOver proc
    call ClearScreen
    mov ah, 02h
    mov bh, 0
    mov dh, 10
    mov dl, 0
    int 10h
    mov dx, offset msgCongrats
    mov ah, 09h
    int 21h
waitForInput:
    mov ah, 00h
    int 16h 
    cmp al, 'y'
    je RestartGame
    cmp al, 'Y'
    je RestartGame
    cmp al, 'n'
    je exitGame
    cmp al, 'N'
    je exitGame
    jmp waitForInput 
RestartGame:
    push ds
    pop es             
    mov cx, 64         
    mov al, 0          
    lea di, statusGrid 
    rep stosb          
    jmp main_init
GameOver endp

GetIndex proc
    xor ax, ax
    mov al, curRow
    mov bl, 8
    mul bl
    add al, curCol
    ret  
GetIndex endp

RedrawFullGrid proc 
    mov di, 0       
    mov dh, 0       
    mov dl, 0       
drawLoop:
    mov ah, 02h
    mov bh, 0
    int 10h
    mov al, statusGrid[di]
    cmp al, 1
    je colorFound
    mov bl, 07h     
    jmp doPrint
colorFound:
    mov bl, 2Fh     
doPrint:
    mov al, grid[di]
    mov cx, 1
    mov ah, 09h
    int 10h
    inc di
    add dl, 2          
    cmp dl, 16      
    jl nextChar
    mov dl, 0
    inc dh
nextChar:
    cmp di, 64
    jl drawLoop
    ret
RedrawFullGrid endp

HighlightCell proc
    mov ah, 02h
    mov bh, 0
    mov dh, curRow
    mov dl, curCol
    shl dl, 1       
    int 10h
    call GetIndex
    mov si, ax
    mov al, grid[si]
    mov ah, 09h
    mov bl, 1Eh     
    mov cx, 1
    int 10h
    ret
HighlightCell endp

UnHighlightCell proc
    mov ah, 02h
    mov bh, 0
    mov dh, curRow
    mov dl, curCol
    shl dl, 1
    int 10h
    call GetIndex
    mov si, ax
    mov bl, statusGrid[si]
    cmp bl, 1
    je restoreFound
    mov bl, 07h     
    jmp applyColor
restoreFound:
    mov bl, 2Fh     
applyColor:
    mov al, grid[si]
    mov ah, 09h
    mov cx, 1
    int 10h
    ret
UnHighlightCell endp

PlayBeep proc
    mov ah, 02h
    mov dl, 07h 
    int 21h
    ret
PlayBeep endp

ShowNotFound proc 
    mov ah, 02h
    mov bh, 0
    mov dh, 11      
    mov dl, 0
    int 10h         
    mov dx, offset msgNotFound
    mov ah, 09h
    int 21h         
    mov cx, 0FFFFh
delay1:
    push cx
    mov cx, 000Fh
delay2:
    loop delay2
    pop cx
    loop delay1
    ret
ShowNotFound endp

SaveWordToFile proc
    push ax
    push bx
    push cx
    push dx
    mov bx, fileHandle
    mov ax, 4202h 
    xor cx, cx
    xor dx, dx
    int 21h
    mov bx, fileHandle
    mov cx, bufLen
    lea dx, inputBuffer 
    mov ah, 40h
    int 21h
    mov bx, fileHandle
    mov cx, 2
    lea dx, newline
    mov ah, 40h
    int 21h
    pop dx
    pop cx
    pop bx
    pop ax
    ret
SaveWordToFile endp

end main