; Portik Mark Krisztian
; 523/2
; BMP projekt

; Grafikus felület argumentumként (parancssorból) megadott 256 színes 
; és true color (24/32 bit) kép megjelenítésére. A kép lehet tömörített is.
; Funkciók (a grafikus felületen található gombok segítségével):
; - kivágás (cropping) - egér segítségével
; - átméretezés (nearest-neighbor) - egér segítségével
; - Gaussian blur
; - (szerkesztett) kép mentése - kiválasztható true color és 256 színes 
;   (konvertálás true colorról) mentés is
; - (szerkesztett) kép tömörítése (RLE) és mentése - kiválasztható 256 
;   színes és true color (ebben az esetben külön-külön tömörítünk az RGB 
;   színattribútumokra) mentés is

; Compile:
; nasm -f win32 bmp.asm
; nlink bmp.obj -lio -lutil -lgfx -o bmp.exe

%include 'io.inc'
%include 'gfx.inc'
%include 'util.inc'

global main

section .text

main:
	call 	getFile
	call 	loadConvert
	mov 	eax,imageBuffer
	mov 	ebx,finalBuffer
	call 	copyBuffer
	
	mov 	ecx, [imageBuffer]
	mov 	[imageWidth], ecx
	mov 	ecx, [imageBuffer + 4]
	mov 	[imageHeight], ecx
	
	call 	loadColorPalette
	call 	icons
	call 	init
	
	.MainLoop:
	
	call 	gfx_map
	
	call 	fillBackground
	
	mov 	ebx, finalBuffer
	mov 	ecx, 0
	mov 	edx, 64
	call 	drawBitmapToBuffer
	
	mov 	edx, 0
	xor 	ecx, ecx
	mov 	ebx, bmpCrop
	call 	drawBitmapToBuffer
	
	mov 	ebx, bmpResize
	add 	ecx, 64
	call 	drawBitmapToBuffer
	
	mov 	ebx, bmpGauss
	add 	ecx, 64
	call 	drawBitmapToBuffer
	
	mov 	ebx, bmpSave
	add 	ecx, 64
	call 	drawBitmapToBuffer
	
	mov 	ebx, bmpSave8
	add 	ecx, 64
	call 	drawBitmapToBuffer
	
	mov 	ebx, bmpSaveCompressed
	add 	ecx, 64
	call 	drawBitmapToBuffer
	
	mov 	ebx, bmpSave8Compressed
	add 	ecx, 64
	call 	drawBitmapToBuffer
	
	call 	gfx_unmap
	call 	gfx_draw
	
	.eventListener:
	call 	gfx_getevent
	
	cmp 	eax, 1
	je 		.clicked
	cmp 	eax, -1
	je 		.released
	cmp 	eax, 23
	je 		.stop
	cmp 	eax, 0
	jnz 	.eventListener
	
	jmp 	.MainLoop
	
	
	.released:
	call 	gfx_getmouse
	cmp 	ebx, 64
	jl 		.eventListener
	mov 	[crop_x1], eax ; y coordinate (end point)
	mov 	[crop_y1], ebx ; x coordinate (end point)
	cmp 	byte [cropOn],0
	jne 	.callCrop
	
	jmp 	.eventListener
	
	.callCrop:
	mov 	byte [cropOn],0
	call 	Crop
	jmp 	.eventListener
	
	.callResize:
	mov 	byte [resizeOn],0
	call 	Resize
	jmp 	.eventListener
	
	.clicked:
	call 	gfx_getmouse
	cmp 	ebx,64
	jl 		.buttons
	
	mov 	[crop_x0],eax
	mov 	[crop_y0],ebx
	
	mov 	[resize_x], eax
	mov 	[resize_y], ebx
	
	cmp 	byte [resizeOn], 0
	jne 	.callResize
	
	mov 	eax,ebx
	jmp 	.eventListener
	
	; Buttons will be placed on NORTH side
	.buttons:
	cmp 	eax, 1
	jl		.eventListener
	
	cmp 	eax, 64
	jl 		.buttonCrop
	
	cmp 	eax, 64 * 2
	jl 		.buttonResize
	
	cmp 	eax, 64 * 3
	jl 		.buttonGauss
	
	cmp 	eax, 64 * 4
	jl 		.buttonSave
	
	cmp 	eax, 64 * 5
	jl 		.buttonSave8
	
	cmp 	eax, 64 * 6
	jl 		.buttonSaveCompressed
	
	cmp 	eax, 64 * 7
	jl 		.buttonSave8Compressed
	
	jmp 	.eventListener
	
	.buttonCrop:
	mov 	byte [cropOn],1
	jmp 	.eventListener
	
	.buttonResize:
	mov 	byte [resizeOn],1
	jmp 	.eventListener
	
	.buttonGauss:
	call 	GaussBlur
	jmp 	.eventListener
	
	.buttonSave:
	call 	Save
	jmp 	.eventListener
	
	.buttonSave8:
	call 	Save8
	jmp 	.eventListener
	
	.buttonSaveCompressed:
	call 	SaveCompressed
	jmp 	.eventListener
	
	.buttonSave8Compressed:
	call 	Save8Compressed
	jmp 	.eventListener
	
	.stop:
	call 	gfx_destroy
	ret
	
; INPUT: -
; OUTPUT: - argumentumokbol ki veszi a file nevet es a file mutatojat le menti
getFile:
	call 	getargs
	.space:
	add 	eax,1

	cmp 	byte [eax], ' '
	jne 	.space
	
	.charLoop:
	add 	eax,1
	
	cmp 	byte [eax],' '
	je 		.charLoop
	
	mov 	[bmpImage], eax
	
	ret
	
; EAX (file name)
; EBX (position)	
loadConvert:
	call 	loadFile
	call 	decompress
	call 	convertGFXbitmap
	
	ret
	
; EAX, EBX
; eax (buffer cime)-bol at masol mindent az ebx (cel buffer)
copyBuffer:
	pusha

	mov 	ecx, [eax]
	mov 	edx, [eax + 4]
	
	mov 	esi, eax
	mov 	edi, ebx
	
	imul 	ecx,edx
	
	inc 	ecx
	inc 	ecx
	
	rep 	movsd
	
	popa
	
	ret
	
; be tolti a memoriaban a file adatai	
loadFile:
	push 	ebx
	push 	ecx
	push 	edx
	push 	esi
	push  	edi
	

	mov 	ebx,0 ; olvasasra
	call 	fio_open
	
	mov 	edi, eax ; file handle
	
	; 14 byte a header a bmp filenak
	mov 	ebx, bmpHeader
	mov 	ecx,14
	call 	fio_read
	
	mov 	eax,[bmpHeader + 2]
	mov 	ecx,eax

	sub 	ecx, 0xE
	
	mov 	ebx, fileBuffer
	add 	ebx, 0xE

	mov 	eax,edi
	call 	fio_read
	
	mov 	eax,edi
	call 	fio_close
	
	mov 	esi,bmpHeader
	mov 	edi,fileBuffer
	mov 	ecx,14
	rep 	movsb
	
	mov 	eax,fileBuffer
	
	pop 	edi
	pop 	esi
	pop 	edx
	pop 	ecx
	pop 	ebx
	
	ret
	
; kitomorites, itt donti el hogy milyen tomorites van
decompress:
	push eax
	cmp 	dword [eax + 30],1 ; nincs tomorites
	jne 		.end
	
	add 	eax, 28
	cmp 	word [eax], 8
	je 		.decompress8
	jmp 	.decompress24
	
	.end:
	pop eax
	ret
	
	.decompress8:
	mov 	ebx,8
	call 	decompress8
	pop 	eax
	ret
	
	.decompress24:
	mov 	ebx,32
	call 	decompress24
	pop 	eax
	ret

; 8 bit valtozatnak a kitomotitese
decompress8:
	pusha
	
	mov 	eax,ebx
	call 	getPaddingSize
	mov 	dword [paddingSize], 0
	
	mov 	esi, fileBuffer
	mov 	edi, imageBuffer

	mov 	ebx, [esi + 10] ; bitmap elotti byteok szama
	mov 	ecx, [esi + 10]
	rep 	movsb
	
	mov 	ecx,0
	mov 	edx,1
	call 	decompressBlock
	
	mov 	ecx, ebx
	mov 	esi, imageBuffer
	mov 	edi, fileBuffer
	
	rep 	movsb
	
	popa
	
	ret
	
; 24 bit kitomotitese
decompress24:
	pusha
	
	mov 	dword [paddingSize],0
	mov 	esi, fileBuffer
	mov 	edi, imageBuffer

	mov 	ecx, [esi + 10]
	mov 	ebx, ecx
	rep 	movsb
	
	mov 	ecx, ebx
	mov 	edx,4
	push 	edi
	call 	decompressBlock
	add 	ecx,ebx
	pop 	edi
	
	inc 	edi
	mov 	edx,4
	push 	edi
	call 	decompressBlock
	add 	ecx,ebx
	pop 	edi
	
	inc 	edi
	mov 	edx,4
	push 	edi
	call 	decompressBlock
	add 	ecx,ebx

	pop 	edi
	
	add 	ecx,ebx ; ures ertekek 
	
	mov 	esi, imageBuffer
	mov 	edi, fileBuffer
	rep 	movsb
	
	mov 	word [fileBuffer + 28], 32
	
	popa
	ret
	
	
; INPUT: ESI, EDI, EDX (offset)
; OUTPUT: EBX
decompressBlock:
	push 	ecx
	push 	ebp
	xor 	ecx,ecx
	xor 	ebx, ebx
	
	.loop:
	cmp 	byte [esi], 0 ; 00 00 vege van a sornak
	jne		.multiply
	
	add 	esi, 1
	
	cmp 	byte [esi], 0 ; 00 00 vege van a sornak
	je 		.endLine
	
	cmp 	byte [esi], 1 ; 00 01 vege van a bitmapnak
	je 		.end
	
	mov 	cl, [esi]
	
	.multiply:
	mov 	cl, [esi]
	mov 	al, [esi + 1]
	add 	esi, 2
	.multiplyLoop:
	mov 	[edi], al
	add 	edi, edx; edx egy offset
	add 	ebx, 1
	loop 	.multiplyLoop
	jmp 	.loop
	
	.endLine:
	add 	esi,1
	add 	esi, [paddingSize]
	jmp 	.loop
	
	.end:
	pop 	ebp
	pop 	ecx
	add esi, 1
	ret
	
; a bitmapet meg forditja es RGB erketekre alakitja megfeleloen
convertGFXbitmap:
	push 	ebx
	push 	ecx
	push 	edx
	push 	esi
	push 	edi
	
	mov 	[bmpImageDrawn], eax
	call 	getSize
	mov 	[height], ebx ; meretek mentese
	mov 	[width], eax ; -//-
	
	mov 	[imageBuffer + 4], ebx ; bufferben valo mentese
	mov 	[imageBuffer], eax ; -//-
	
	; depth erteke (8, 24 vagy 32)
	mov 	eax, [bmpImageDrawn]
	call 	getBitDepth
	mov 	[depth], ebx
	
	; padding erteke (kitolto bitek)
	mov 	eax,[width]
	mov 	ebx,[depth]
	call 	getPaddingSize
	mov 	[paddingSize], eax
	
	mov 	edx,[bmpImageDrawn]
	add 	edx,10
	
	mov 	eax,[edx]
	add 	eax,[bmpImageDrawn] ; offset
	mov 	edx,eax
		
	mov 	ecx, [height]
	
	mov 	edi, [width]
	imul 	edi, [height]
	imul 	edi, 4
	
	add 	edi, imageBuffer
	add 	edi, 8
	
	.drawY:
	sub 	edi, [width]
	sub 	edi, [width]
	sub 	edi, [width]
	sub 	edi, [width]
	dec 	ecx
	mov 	esi,0
	.drawX:
	inc 	esi
	
	cmp 	dword [depth], 8
	je 		.draw8bit
	cmp 	dword [depth], 24
	je 		.draw24bit
	cmp 	dword [depth], 32
	je 		.draw32bit
	jmp 	.exitDraw
	
	; bitmapen belul mindig 4-el oszhato szamu cimen kell kezdodjon egy sor
	
	.continueDraw:
	cmp 	esi, [width]
	jl		.drawX
	
	add 	edx, [paddingSize]
	; kitolto biteket ki hagyjuk
	
	sub 	edi, [width]
	sub 	edi, [width]
	sub 	edi, [width]
	sub 	edi, [width]
	cmp 	ecx,0
	jg 		.drawY
	
	.exitDraw:
	
	pop 	edi
	pop 	esi
	pop 	edx
	pop 	ecx
	pop 	ebx
	
	ret
	
.draw8bit:
	push 	ecx
	push 	eax
	
	; palettaban ki keressuk a megfelelo szint
	mov 	eax, [bmpImageDrawn]
	xor 	ecx, ecx
	add 	eax, 54
	
	mov 	cl, [edx]
	imul 	ecx,4
	add 	eax,ecx
	
	; kek
	mov 	bl, [eax]
	mov 	[edi], bl
	inc 	eax
	inc 	edi
	
	; zold
	mov 	bl, [eax]
	mov 	[edi], bl
	inc 	eax
	inc 	edi
	
	; piros
	mov 	bl, [eax]
	mov 	[edi], bl
	inc 	eax
	inc 	edi
	
	mov 	bl, 0
	mov 	[edi], bl
	inc 	eax
	inc 	edi
	
	inc edx
	
	pop 	eax
	pop 	ecx

	jmp		.continueDraw
	

.draw24bit:
	push 	ecx
	
	; kek
	mov 	cl, [edx]
	mov 	[edi],cl
	add 	edx,1
	add 	edi,1
	; zold
	mov 	cl, [edx]
	mov 	[edi], cl
	add 	edx,1
	add 	edi,1
	; piros
	mov 	cl, [edx]
	mov 	[edi], cl
	add 	edx,1
	add 	edi,1
	
	mov 	byte [edi], 0
	add 	edi,1
	
	pop 	ecx
	jmp 	.continueDraw

.draw32bit:
	push 	ecx
	; kek
	mov 	cl, [edx]
	mov 	[edi],cl
	add 	edx,1
	add 	edi,1
	; zold
	mov 	cl, [edx]
	mov 	[edi], cl
	add 	edx,1
	add 	edi,1
	; piros
	mov 	cl, [edx]
	mov 	[edi], cl
	add 	edx,1
	add 	edi,1
	
	mov 	byte [edi], 0
	add 	edi,1
	add 	edx,1
	
	pop 	ecx
	jmp 	.continueDraw
	
; itt donti el hogy milyen depth-el rendelkezik a kep (8, 24, 32)
getBitDepth:
	push 	eax
	
	mov 	ebx,0
	add 	eax, 28
	mov 	bx, [eax]
	
	pop 	eax
	
	ret

; ki toltok bitek merete
getPaddingSize:
	push 	ebx
	
	cmp 	ebx,32
	je 		.end32
	cmp 	ebx,8
	je 		.check
	
	imul 	eax,3
	.check:
	mov 	ebx,0
	test 	eax,3
	je 		.end
	
	inc 	eax
	inc 	ebx
	test 	eax,3
	je 		.end
	
	inc 	eax
	inc 	ebx
	test 	eax,3
	je 		.end
	
	inc 	eax
	inc 	ebx
	test 	eax,3
	je 		.end
	
	.end:
	mov 	eax,ebx
	
	pop 	ebx
	
	ret
	
	.end32:
	xor 	eax,eax
	
	pop 	ebx
	ret

; EAX - pointer
; EAX - width, EBX - height	
getSize:
	push 	ecx
	
	mov 	ecx, eax
	
	add 	eax, 18
	mov 	ecx, [eax]
	
	add 	eax, 4
	mov 	ebx, [eax]
	
	mov 	eax, ecx
	
	pop 	ecx
	
	ret
	
Crop:
	pusha

	mov 	eax,fileIconCrop
	call 	io_writestr
	call 	io_writeln
	
	
	mov 	esi, finalBuffer
	mov 	edi, imageBuffer
	
	; hiba kezeles
	mov 	eax, [crop_x0]
	mov 	ebx, [crop_x1]
	mov 	ecx, [crop_y0]
	mov 	edx, [crop_y1]
	
	sub 	ebx, eax ; uj szelleseg
	
	sub 	edx, ecx ; uj magassag
	
	; uj meretek mentese
	mov 	[width], ebx
	mov 	[height], edx
	
	; bufferben az uj meretek mentese
	mov 	[edi], ebx
	add 	edi, 4
	mov 	[edi], edx
	add 	edi,4
	add 	esi,8
	
	mov 	eax, [crop_x0]
	mov 	ebx, [crop_x1]
	mov 	ecx, [crop_y0]
	mov 	edx, [crop_y1]
	
	sub 	ecx,64 ; gombok miatt
	sub 	edx,64
	
	imul 	ecx,4
	
	; y1 * 4 * magassag adunk hozza (skipelli a sorokat)
	.y_loop:
	
	add 	esi, [imageWidth]
	loop	.y_loop
	
	mov 	ecx,[imageWidth]
	sub 	ecx, ebx
	mov 	ebx, ecx
	
	imul 	ebx,4
	
	mov 	ecx,[height]
	imul 	eax,4 ; 4 ertek == pixel
	
	; mindengyik sorban at ugrunk x0 ig es onnan y1 ig hozza at masoljuk 
	.x_loop:
	add 	esi,eax

	mov 	edx, ecx
	mov 	ecx,[width]
	
	rep 	movsd
	
	mov 	ecx,edx
	
	add 	esi,ebx
	
	loop 	.x_loop
	
	mov 	eax, imageBuffer
	mov 	ebx, finalBuffer
	call 	copyBuffer
	
	mov 	edx,[height]
	mov 	[imageHeight],edx
	mov 	edx,[width]
	mov 	[imageWidth], edx
	
	popa
	
	ret
Resize:

	pusha
	mov 	eax,fileIconResize
	call 	io_writestr
	call 	io_writeln
	
	mov 	esi, finalBuffer
	mov 	edi, imageBuffer
	
	mov 	eax, [resize_x]
	mov 	ebx, [resize_y]
	sub 	ebx, 64 ; gombok miatt
	
	; uj mereteket le mentsuk a memoriaban
	mov 	[width], eax
	mov 	[height], ebx
	
	mov 	[edi], eax
	add 	edi, 4
	mov 	[edi], ebx
	add 	edi, 4
	add 	esi, 8
	
	; kiszamoljuk hogy egy oszlopban az eredeti kepbol a pixelje hogy hanyadik helyre kell keruljon
	cvtsi2ss	xmm0, [imageHeight]
	cvtsi2ss	xmm1, [height]
	divss 		xmm0, xmm1

	mov 	ecx, [height]
	.interpolation_row:
	cvtsi2ss 	xmm1, ecx
	mulss 		xmm1, xmm0
	cvttss2si 	edx, xmm1
	mov 		[interpolation_index_row + ecx * 4], edx
	
	loop 	.interpolation_row
	
	; ; kiszamoljuk hogy egy sorban az eredeti kepbol a pixelje hogy hanyadik helyre kell keruljon
	cvtsi2ss	xmm0, [imageWidth]
	cvtsi2ss	xmm1, [width]
	divss 		xmm0, xmm1

	mov 	ecx, [width]
	.interpolation_column:
	cvtsi2ss 	xmm1, ecx
	mulss 		xmm1, xmm0 ; index * (eredeti magassag / uj magassag)
	cvttss2si 	edx, xmm1
	mov 		[interpolation_index_column + ecx * 4], edx
	
	loop 	.interpolation_column
	
	; fuggoleges tengely menten vegezzuk az atmeretezest
	mov		ecx, 0
	.loopY:
	mov 	ebx, 0
	mov 	edi, imageBuffer
	add 	edi, 8
	
	push 	ecx
	imul 	ecx, 4 ; oszlopokan hosszan jarjuk be
	add 	edi, ecx
	
	pop 	ecx
	
	.loopRow:
	mov 	eax, [interpolation_index_row + ebx * 4] ; interpolacio tomb alapjan lesz ki valasztva az uj ertek
	imul 	eax, 4
	imul 	eax, [imageWidth]
	
	add 	esi, eax
	
	mov 	edx, [esi]
	mov 	[edi], edx
	
	sub 	esi, eax
	
	push 	ecx
	mov 	ecx, 4
	.nextRow:
	
	add 	edi, [imageWidth]
	loop 	.nextRow
	pop 	ecx
	
	add 	ebx,1
	cmp 	ebx, [height]
	jl 		.loopRow
	
	inc 	ecx
	add 	esi, 4
	cmp 	ecx,[imageWidth]
	jl 		.loopY
	
	; ki mentjuk az uj ertekeket
	pusha
	mov 	eax, [height]
	mov 	ebx, [imageWidth]
	mov 	[imageBuffer +4] , eax
	mov 	[imageBuffer], ebx
	mov 	eax, imageBuffer
	mov 	ebx, finalBuffer
	call 	copyBuffer
	popa
	
	mov 	edi, imageBuffer
	mov 	esi, finalBuffer
	
	add esi, 8
	add edi, 8
	
	; vizszintes tengely menten vegezzuk az atmeretezest
	mov		ecx, 0
	.loopX:
	mov 	ebx, 0
	
	.loopColumn:
	mov 	eax, [interpolation_index_column + ebx * 4] ; interpolacios tombbol ki valasztja a megfelelo erteket
	imul 	eax, 4
	
	add 	esi, eax
	
	mov 	edx, [esi]
	mov 	[edi], edx
	
	sub 	esi, eax
	
	; kov. sor
	add 	edi, 4
	
	add 	ebx,1
	cmp 	ebx, [width]
	jl 		.loopColumn
	
	add 	esi, [imageWidth]
	add 	esi, [imageWidth]
	add 	esi, [imageWidth]
	add 	esi, [imageWidth]
	
	inc 	ecx
	
	cmp 	ecx,[height]
	jl 		.loopX

	; atmasolas
	mov eax, [height]
	mov ebx, [width]
	mov [imageBuffer +4] , eax
	mov [imageBuffer], ebx
	mov 	eax, imageBuffer
	mov 	ebx, finalBuffer
	call 	copyBuffer
	
	mov 	ecx, [height]
	mov 	[imageHeight], ecx
	
	mov 	ecx, [width]
	mov 	[imageWidth], ecx
	
	popa

	ret
	
GaussBlur:

	pusha
	mov 	eax,fileIconGauss
	call 	io_writestr
	call 	io_writeln
	
	; meretek 
	mov 	esi, finalBuffer
	mov 	eax, [esi]
	add 	esi, 4
	mov 	ebx, [esi]
	add 	esi, 4
	; hova kerulnek be az uj ertekek
	mov 	edi, imageBuffer
	; meretek atmasolasa
	mov 	[edi], eax
	mov 	[edi + 4], ebx
	mov 	ecx, eax
	add 	edi, 8
	
	rep 	movsd
	; elso sor az ugyan ugy marad
	sub 	ebx, 1
	
	.loopY:
	dec 	ebx
	
	mov 	ecx, eax
	imul 	ecx, 4
	
	movsd
	
	.loopX:
	dec 	ecx
	
	movss 	xmm0, [zero]
	
	push 	ecx
	
	mov 	ecx,4
	.adjust:
	sub 	esi, eax
	loop 	.adjust
	
	sub 	esi, 4
	pop 	ecx
	
	mov 	edx,0
	mov 	dl, [esi]
	cvtsi2ss 	xmm1, edx
	mulss 		xmm1, [gaussKernelTopBottom]
	add 	esi, 4
	addss 		xmm0, xmm1
	
	mov 	edx,0
	mov 	dl, [esi]
	cvtsi2ss 	xmm1, edx
	mulss 		xmm1, [gaussKernelTopBottom + 4]
	add 	esi, 4
	addss 		xmm0, xmm1
	
	mov 	edx,0
	mov 	dl, [esi]
	cvtsi2ss 	xmm1, edx
	mulss 		xmm1, [gaussKernelTopBottom + 8]
	sub 	esi, 4
	addss 		xmm0, xmm1
	
	push 	ecx
	mov 	ecx,4
	.middle_adjust:
	add 	esi, eax
	loop 	.middle_adjust
	
	sub 	esi, 4
	pop 	ecx
	
	mov 	edx,0
	mov 	dl, [esi]
	cvtsi2ss 	xmm1, edx
	mulss 		xmm1, [gaussKernelMiddle]
	add 	esi, 4
	addss 		xmm0, xmm1
	
	mov 	edx,0
	mov 	dl, [esi]
	cvtsi2ss 	xmm1, edx
	mulss 		xmm1, [gaussKernelMiddle + 4]
	add 	esi, 4
	addss 		xmm0, xmm1
	
	mov 	edx,0
	mov 	dl, [esi]
	cvtsi2ss 	xmm1, edx
	mulss 		xmm1, [gaussKernelMiddle + 8]
	sub 	esi, 4
	addss 		xmm0, xmm1
	
	push 	ecx
	mov 	ecx,4
	.bottom_adjust:
	add 	esi, eax
	loop 	.bottom_adjust
	
	sub 	esi, 4
	pop 	ecx
	
	mov 	edx,0
	mov 	dl, [esi]
	cvtsi2ss 	xmm1, edx
	mulss 		xmm1, [gaussKernelTopBottom]
	add 	esi, 4
	addss 		xmm0, xmm1
	
	mov 	edx,0
	mov 	dl, [esi]
	cvtsi2ss 	xmm1, edx
	mulss 		xmm1, [gaussKernelTopBottom + 4]
	add 	esi, 4
	addss 		xmm0, xmm1
	
	mov 	edx,0
	mov 	dl, [esi]
	cvtsi2ss 	xmm1, edx
	mulss 		xmm1, [gaussKernelTopBottom + 8]
	sub 	esi, 4
	addss 		xmm0, xmm1
	
	push 	eax
	cvtss2si 	eax, xmm0
	stosb
	pop 	eax
	
	push 	ecx
	mov 	ecx,4
	.adjust_original:
	sub 	esi, eax
	loop 	.adjust_original
	pop 	ecx
	
	inc 	esi
	
	cmp 	ecx, 4
	jg 		.loopX
	cmp 	ebx, 1
	jg 		.loopY
	
	mov 	ecx, eax
	rep 	movsd
	
	mov 	eax, imageBuffer
	mov 	ebx, finalBuffer
	call 	copyBuffer
	
	popa
	
	ret
	
Save:
	pusha
	
	mov 	eax,fileIconSave
	call 	io_writestr
	call 	io_writeln
	
	mov 	esi, finalBuffer
	mov 	ebx, [esi]
	add 	esi, 4
	mov 	ecx, [esi]
	add 	esi, 4
	
	imul 	ebx, 3
	mov		eax, ebx
	call 	divisibleBy4
	
	imul 	eax,ecx
	
	add 	eax,54 ; header
	
	mov 	byte [bmpHeader], 'B'
	mov 	byte [bmpHeader + 1], 'M'
	mov 	[bmpHeader + 2], eax
	mov 	dword [bmpHeader + 10], 54 ; bitmap kezdete
	
	mov 	eax, newString
	call 	io_writestr
	mov 	eax, filename
	call 	io_readstr
	call 	io_writeln
	
	mov 	ebx,1
	call 	fio_open
	
	mov 	ebx, bmpHeader ; be masolja a headert az uj fileban
	mov 	ecx, 14
	call 	fio_write
	
	mov 	esi, finalBuffer
	mov 	ebx, [esi]
	add 	esi, 4
	mov 	ecx, [esi]
	add 	esi, 4
	mov 	dword [bitmapinfoheader], 40
	mov 	[bitmapinfoheader + 4], ebx ; szelleseg
	mov 	[bitmapinfoheader + 8], ecx ; magassag
	mov 	word [bitmapinfoheader + 12], 1 ; color planes
	mov 	word [bitmapinfoheader + 14], 24 ; depth
	mov 	dword [bitmapinfoheader + 16], 0 ; nincs tomorites
	mov 	dword [bitmapinfoheader + 20], 0 ; nem kell kezdo ertek mert nincs tomorites
	mov 	dword [bitmapinfoheader + 24], 0 ; felbontas (lenyegtelen)
	mov 	dword [bitmapinfoheader + 28], 0 ; felbontas (lenyegtelen)
	mov 	dword [bitmapinfoheader + 32], 0 ; nem hasznalunk palettat
	mov 	dword [bitmapinfoheader + 36], 0 ; minden szint fontos, nincs jelentosege
	
	; bitmapinfoheader beirasa a fileban
	mov 	ebx, bitmapinfoheader
	mov 	ecx, 40
	call 	fio_write
	
	mov 	edx, [finalBuffer + 4]
	mov 	ebx, [finalBuffer]
	
	imul 	ebx,4
	mov 	ecx,edx
	
	.loop:
	add 	esi,ebx
	loop 	.loop
	mov 	ebp,[imageHeight]
	.loopY:
	mov 	edi, imageBuffer
	mov 	ecx, 0
	.copy:
	movsb
	movsb
	movsb
	inc 	esi
	inc 	ecx
	cmp 	ecx, [imageWidth]
	jl 		.copy
	
	xchg 	eax, edx
	mov 	eax, [bitmapinfoheader + 4]
	imul 	eax, 3
	call 	divisibleBy4
	imul 	ecx, 3
	
	.pad:
	cmp 	eax,ecx
	je 		.end
	mov 	byte [edi],0
	add 	edi,1
	add 	ecx,1
	jmp 	.pad
	
	.end:
	xchg 	eax,edx
	mov 	ebx,imageBuffer
	
	call 	fio_write
	
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	
	dec 	ebp
	cmp 	ebp,0
	jg 		.loopY
	
	call 	fio_close
	
	popa

	ret
	
SaveCompressed:
	pusha
	
	mov 	eax,fileIconSaveCompressed
	call 	io_writestr
	call 	io_writeln
	
	mov 	esi, finalBuffer
	mov 	ebx, [esi]
	add 	esi, 4
	mov 	ecx, [esi]
	add 	esi, 4
	
	imul 	ebx, 3
	mov		eax, ebx
	call 	divisibleBy4
	
	imul 	eax,ecx
	
	add 	eax,54 ; header
	
	mov 	byte [bmpHeader], 'B'
	mov 	byte [bmpHeader + 1], 'M'
	mov 	[bmpHeader + 2], eax
	mov 	dword [bmpHeader + 10], 54 ; bitmap kezdete
	
	mov 	eax, newString
	call 	io_writestr
	mov 	eax, filename
	call 	io_readstr
	call 	io_writeln
	
	mov 	ebx,1 ; olvasasra
	call 	fio_open
	
	mov 	ebx, bmpHeader ; be masolja a headert az uj fileban
	mov 	ecx, 14
	call 	fio_write
	; meretek
	mov 	esi, finalBuffer
	mov 	ebx, [esi]
	add 	esi, 4
	mov 	ecx, [esi]
	add 	esi, 4
	mov 	dword [bitmapinfoheader], 40
	mov 	[bitmapinfoheader + 4], ebx ; szelleseg
	mov 	[bitmapinfoheader + 8], ecx ; magassag
	mov 	word [bitmapinfoheader + 12], 1 ; color planes
	mov 	word [bitmapinfoheader + 14], 24; 24 depth (bites)
	mov 	dword [bitmapinfoheader + 16], 1 ; van tomorites
	mov 	dword [bitmapinfoheader + 20], 0 ; nem szamit
	mov 	dword [bitmapinfoheader + 24], 0 ; felbontas (PRINT)
	mov 	dword [bitmapinfoheader + 28], 0 ; felbontas (PRINT)
	mov 	dword [bitmapinfoheader + 32], 0 ; nem hasznal szines palettat
	mov 	dword [bitmapinfoheader + 36], 0 ; nincs jelentosege
	
	; be irjuk a bitmapinfoheader
	mov 	ebx, bitmapinfoheader
	mov 	ecx, 40
	call 	fio_write
	
	mov 	edx, [finalBuffer + 4]
	mov 	ebx, [finalBuffer]
	
	imul 	ebx,4
	mov 	ecx,edx
	; kek
	.loop:
	add 	esi,ebx
	loop 	.loop
	
	push 	esi
	mov 	ebp,[imageHeight]
	.loopY:
	mov 	edi, imageBuffer
	mov 	ecx, 0
	.copy:
	movsb
	inc 	esi
	inc 	esi
	inc 	esi
	inc 	ecx
	cmp 	ecx, [imageWidth]
	jl 		.copy
	
	pusha
	mov 	ebx, imageBuffer
	mov 	ecx, [imageWidth]
	dec ecx
	
	call 	compress ; tomoritunk egy sort
	
	mov 	ecx,edx
	call 	fio_write
	popa
	
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	
	dec 	ebp
	cmp 	ebp,0
	jg 		.loopY
	; 00 01 jeloli a szin veget
	; 
	pusha
	mov 	ebx, bitmapinfoheader
	mov 	byte [bitmapinfoheader], 0
	mov 	byte [bitmapinfoheader + 1], 1
	mov 	ecx, 2
	call 	fio_write
	popa
	
	pop esi 
	push esi
	
	mov 	ebp,[imageHeight]
	; zold
	.loopY1:
	mov 	edi, imageBuffer
	mov 	ecx, 0
	.copy1:
	inc 	esi
	movsb
	inc 	esi
	inc 	esi
	inc 	ecx
	cmp 	ecx, [imageWidth]
	jl 		.copy1
	
	pusha
	mov 	ebx, imageBuffer
	mov 	ecx, [imageWidth]
	dec 	ecx

	call 	compress
	
	mov 	ecx,edx
	call 	fio_write
	popa
	
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	
	dec 	ebp
	cmp 	ebp,0
	jg 		.loopY1

	pusha
	mov 	ebx, bitmapinfoheader
	mov 	byte [bitmapinfoheader], 0
	mov 	byte [bitmapinfoheader + 1], 1
	mov 	ecx, 2
	call 	fio_write
	popa
	
	
	pop esi 
	
	mov 	ebp,[imageHeight]
	
	; piros
	.loopY2:
	mov 	edi, imageBuffer
	mov 	ecx, 0
	.copy2:
	inc 	esi
	inc 	esi
	movsb
	inc 	esi
	inc 	ecx
	cmp 	ecx, [imageWidth]
	jl 		.copy2
	
	pusha
	mov 	ebx, imageBuffer
	mov 	ecx, [imageWidth]
	dec		ecx

	
	call 	compress
	
	mov 	ecx,edx
	call 	fio_write
	popa
	
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	
	dec 	ebp
	cmp 	ebp,0
	jg 		.loopY2
	
	pusha
	mov 	ebx, bitmapinfoheader
	mov 	byte [bitmapinfoheader], 0
	mov 	byte [bitmapinfoheader + 1], 1
	mov 	ecx, 2
	call 	fio_write
	popa
	
	call 	fio_close
	
	popa

	ret
	
Save8:
	pusha
	
	mov 	eax,fileIconSave8
	call 	io_writestr
	call 	io_writeln
	
	mov 	esi, finalBuffer
	mov 	ebx, [esi]
	add 	esi, 4
	mov 	ecx, [esi]
	add 	esi, 4
	
	imul 	ebx, 3
	mov		eax, ebx
	call 	divisibleBy4
	
	imul 	eax,ecx
	
	add 	eax,54 ; header
	
	mov 	byte [bmpHeader], 'B'
	mov 	byte [bmpHeader + 1], 'M'
	mov 	[bmpHeader + 2], eax
	mov 	dword [bmpHeader + 10], 1078 ; bitmap kezdete
	
	mov 	eax, newString
	call 	io_writestr
	mov 	eax, filename
	call 	io_readstr
	call 	io_writeln
	
	mov 	ebx,1
	call 	fio_open
	
	mov 	ebx, bmpHeader ; be masolja a headert az uj fileban
	mov 	ecx, 14
	call 	fio_write
	
	mov 	esi, finalBuffer
	mov 	ebx, [esi]
	add 	esi, 4
	mov 	ecx, [esi]
	add 	esi, 4
	mov 	dword [bitmapinfoheader], 40
	mov 	[bitmapinfoheader + 4], ebx
	mov 	[bitmapinfoheader + 8], ecx
	mov 	word [bitmapinfoheader + 12], 1 
	mov 	word [bitmapinfoheader + 14], 8
	mov 	dword [bitmapinfoheader + 16], 0
	mov 	dword [bitmapinfoheader + 20], 0
	mov 	dword [bitmapinfoheader + 24], 0
	mov 	dword [bitmapinfoheader + 28], 0
	mov 	dword [bitmapinfoheader + 32], 256
	mov 	dword [bitmapinfoheader + 36], 0
	
	mov 	ebx, bitmapinfoheader
	mov 	ecx, 40
	call 	fio_write
	
	mov 	ebx, colorPalette
	mov 	ecx, 1024
	call 	fio_write
	
	mov 	edx, [finalBuffer + 4]
	mov 	ebx, [finalBuffer]
	
	imul 	ebx,4
	mov 	ecx,edx
	
	.loop:
	add 	esi,ebx
	loop 	.loop
	mov 	ebp,[imageHeight]
	.loopY:
	mov 	edi, imageBuffer
	mov 	ecx, 0
	; szin indexet ki szamolasa
	; 3 - piros
	; 3 - zold
	; 2 - kek
	; kiszamoljuk a meg felelo szin indexet a szines paletta alapjan
	.copy:
	push 	eax
	push 	ebx
	
	mov 	ebx,0
	
	mov 	al, [esi]
	shr 	al, 6
	add 	bl, al
	inc 	esi
	
	mov 	al, [esi]
	shr 	al, 5
	shl 	al, 2
	add 	bl, al
	inc 	esi
	
	mov 	al, [esi]
	shr 	al, 5
	shl 	al, 5
	add 	bl, al
	inc 	esi
	
	mov 	[edi],bl
	
	pop 	ebx
	pop 	eax
	
	inc 	esi
	inc 	edi
	inc 	ecx
	cmp 	ecx, [imageWidth]
	jl 		.copy
	
	xchg 	eax, edx
	mov 	eax, [bitmapinfoheader + 4]
	call 	divisibleBy4
	
	.pad:
	cmp 	eax,ecx
	je 		.end
	mov 	byte [edi],0
	add 	edi,1
	add 	ecx,1
	jmp 	.pad
	
	.end:
	xchg 	eax,edx
	mov 	ebx,imageBuffer
	
	call 	fio_write
	
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	
	dec 	ebp
	cmp 	ebp,0
	jg 		.loopY
	
	call 	fio_close
	
	popa

	ret
	
Save8Compressed:
	pusha
	mov 	eax,fileIconSave8Compressed
	call 	io_writestr
	call 	io_writeln

	mov 	esi, finalBuffer
	mov 	ebx, [esi]
	add 	esi, 4
	mov 	ecx, [esi]
	add 	esi, 4
	
	imul 	ebx, 3
	mov		eax, ebx
	call 	divisibleBy4
	
	imul 	eax,ecx
	
	add 	eax,54 ; header
	
	mov 	byte [bmpHeader], 'B'
	mov 	byte [bmpHeader + 1], 'M'
	mov 	[bmpHeader + 2], eax
	mov 	dword [bmpHeader + 10], 1078 ; bitmap kezdete
	
	mov 	eax, newString
	call 	io_writestr
	mov 	eax, filename
	call 	io_readstr
	call 	io_writeln
	
	mov 	ebx,1
	call 	fio_open
	
	mov 	ebx, bmpHeader ; be masolja a headert az uj fileban
	mov 	ecx, 14
	call 	fio_write
	
	mov 	esi, finalBuffer
	mov 	ebx, [esi]
	add 	esi, 4
	mov 	ecx, [esi]
	add 	esi, 4
	mov 	dword [bitmapinfoheader], 40
	mov 	[bitmapinfoheader + 4], ebx ; kep szellesege
	mov 	[bitmapinfoheader + 8], ecx ; kep magassaga
	mov 	word [bitmapinfoheader + 12], 1 ; color planes
	mov 	word [bitmapinfoheader + 14], 8 ; bit
	mov 	dword [bitmapinfoheader + 16], 1 ; tomotites
	mov 	dword [bitmapinfoheader + 20], 0 ; tomoritetnek a merete
	mov 	dword [bitmapinfoheader + 24], 0 ; felbontas (PRINT) 
	mov 	dword [bitmapinfoheader + 28], 0 ; felbontas (PRINT)
	mov 	dword [bitmapinfoheader + 32], 256 ; hany szin van a palettaban
	mov 	dword [bitmapinfoheader + 36], 0
	
	; bitmapinfoheader mentese
	mov 	ebx, bitmapinfoheader
	mov 	ecx, 40
	call 	fio_write
	
	; szines paletta mentese
	mov 	ebx, colorPalette
	mov 	ecx, 1024
	call 	fio_write
	
	mov 	edx, [finalBuffer + 4]
	mov 	ebx, [finalBuffer]
	
	imul 	ebx,4
	mov 	ecx,edx
	
	.loop:
	add 	esi,ebx
	loop 	.loop
	mov 	ebp,[imageHeight]
	.loopY:
	mov 	edi, imageBuffer
	mov 	ecx, 0
	; szin indexet ki szamolasa
	; 3 - piros
	; 3 - zold
	; 2 - kek
	; kiszamoljuk a meg felelo szin indexet a szines paletta alapjan
	.copy:
	push 	eax
	push 	ebx
	
	mov 	ebx,0
	
	mov 	al, [esi]
	shr 	al, 6
	add 	bl, al
	inc 	esi
	
	mov 	al, [esi]
	shr 	al, 5
	shl 	al, 2
	add 	bl, al
	inc 	esi
	
	mov 	al, [esi]
	shr 	al, 5
	shl 	al, 5
	add 	bl, al
	inc 	esi
	
	mov 	[edi],bl
	
	pop 	ebx
	pop 	eax
	
	inc 	esi
	inc 	edi
	inc 	ecx
	cmp 	ecx, [imageWidth]
	jl 		.copy
	
	xchg 	eax, edx
	
	
	.end:
	push 	edx
	mov 	ebx, imageBuffer
	dec 	ecx
	call 	compress
	
	mov 	ecx,edx
	pop 	edx
	
	xchg 	eax,edx
	mov 	ebx,imageBuffer
	
	call 	fio_write
	
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	sub 	esi, [imageWidth]
	
	dec 	ebp
	cmp 	ebp,0
	jg 		.loopY
	
	mov 	ebx, bitmapinfoheader
	mov 	byte [bitmapinfoheader], 0
	mov 	byte [bitmapinfoheader + 1], 1
	mov 	ecx, 2
	call 	fio_write
	
	call 	fio_close
	
	popa

	ret

; INPUT: EBX(pointer), ECX(length) 
; OUTPUT: EDX(compressed length)
compress:
	push 	eax
	push 	ebx
	push 	ecx
	push 	edi
	push 	esi
	
	mov 	esi, ebx ; mutato
	push 	ebx
	mov 	edi, compressBuffer ; ide masoljuk a tomoritett format
	mov 	eax,0
	xor 	ebx,ebx
	inc 	eax
	
	.loop:
	cmp 	al, 255
	je 		.save
	inc 	al
	mov 	ah, [esi]
	inc 	esi
	inc 	ebx
	cmp 	ah, [esi]
	jne 	.save ; addig megy a meddig a ket elem egyenloek.
	cmp 	ebx,ecx
	jl 		.loop
	
	; le menti az adott pixel erteket es hogy hany darab van
	.save:
	mov 	[edi], al
	inc 	edi
	mov 	[edi], ah
	inc 	edi
	mov 	al, 0
	cmp 	ebx, ecx
	jl 	.loop
	
	mov 	byte [edi],0
	inc 	edi
	mov 	byte [edi],0
	inc 	edi
	
	mov 	edx, edi
	sub 	edx, compressBuffer
	
	pop 	ebx
	mov 	ecx, edx
	mov 	esi, compressBuffer
	mov 	edi, ebx
	rep 	movsb
	; vissza masoljuk a tomoritett format az adott mutatora
	
	pop 	esi
	pop 	edi
	pop 	ecx
	pop 	ebx
	pop 	eax
	
	ret

; INPUT  : - 
; OUTPUT : Loads all the necessary files for the buttons/icons
icons:
	push 	eax
	push 	ebx
	
	mov 	eax, fileIconCrop
	call 	loadConvert
	mov 	eax,imageBuffer
	mov 	ebx,bmpCrop
	call 	copyBuffer
	
	mov 	eax, fileIconGauss
	call 	loadConvert
	mov 	eax,imageBuffer
	mov 	ebx,bmpGauss
	call 	copyBuffer
	
	mov 	eax, fileIconResize
	call 	loadConvert
	mov 	eax,imageBuffer
	mov 	ebx,bmpResize
	call 	copyBuffer
	
	mov 	eax, fileIconSave
	call 	loadConvert
	mov 	eax,imageBuffer
	mov 	ebx,bmpSave
	call 	copyBuffer
	
	mov 	eax, fileIconSave8
	call 	loadConvert
	mov 	eax,imageBuffer
	mov 	ebx,bmpSave8
	call 	copyBuffer
	
	mov 	eax, fileIconSaveCompressed
	call 	loadConvert
	mov 	eax,imageBuffer
	mov 	ebx,bmpSaveCompressed
	call 	copyBuffer
	
	mov 	eax, fileIconSave8Compressed
	call 	loadConvert
	mov 	eax,imageBuffer
	mov 	ebx,bmpSave8Compressed
	call 	copyBuffer
	
	pop 	ebx
	pop 	eax
	
	ret
	
;INPUT  : - 
;OUTPUT : Initialize the window
init:
	pusha
	
	mov 	eax,[imageHeight]
	call 	divisibleBy4
	mov 	[windowHeight], eax

	mov 	eax, [imageWidth]
	call 	divisibleBy4
	mov 	ecx, 64 * 7
	cmp 	eax, ecx
	jg 		.skip
	
	mov 	eax,ecx
	
	.skip:
	
	mov 	[windowWidth], eax
	
	mov 	eax, [windowHeight]
	add 	eax,64
	mov 	[windowHeight], eax
	
	
	mov 	edx, windowText
	mov 	ecx, 0
	mov 	eax, [windowWidth]
	mov 	ebx, [windowHeight]
	
	call 	gfx_init
	popa
	
	ret
	
; INPUT : EAX (egy szam)
; OUTPUT: EAX (egy olyan szamra noveli a meddig oszhato lesz 4-el)
divisibleBy4:
	
	test 	eax,3
	je 		.end
	
	inc 	eax
	test 	eax,3
	je 		.end
	
	inc 	eax
	test 	eax,3
	je 		.end
	
	inc 	eax
	test 	eax,3
	je 		.end
	
	inc 	eax
	test 	eax,3
	je 		.end
	
	inc 	eax
	test 	eax,3
	je 		.end
	
	inc 	eax
	test 	eax,3
	je 		.end
	
	inc 	eax
	test 	eax,3
	je 		.end

	.end:
	
	ret
	

;INPUT  : - 
;OUTPUT : fill the window/background with the color white
fillBackground:
	pusha
	
	mov 	ecx,[windowHeight];
	imul 	ecx,[windowWidth];
	
	.fillUp:
		mov 	dword [eax], 0x00FFFFFF ; white
		add 	eax,4
	loop .fillUp
	
	popa
	
	ret
	
; INPUT : 
; EAX (gfx puffer), 
; EBX (image pointer), 
; ECX (x position), 
; EDX(y position)
; OUTPUT: copies the pixels into gfx puffer
drawBitmapToBuffer:
	push 	eax
	push 	ebx
	push 	ecx
	push 	edx
	push 	esi
	push 	edi
	push 	ebp
	push 	esp
	
	
	mov 	edi, eax ; ide masolunk
	mov 	esi, ebx ; innen masolunk
	
	; bmp kep meretei
	mov 	eax, [esi]
	add 	esi, 4
	mov 	ebx, [esi]
	add 	esi, 4
	
	; hany pixel kell az ablaknak
	mov 	ebp, [windowWidth]
	sub 	ebp, ecx
	sub 	ebp, eax
	imul 	ebp, 4
	
	imul 	edx,4
	
	; 0,Y pozicio
	.loopY:
	cmp 	edx,0
	je 		.drawLoopSetup
	add 	edi,[windowWidth]
	dec 	edx	
	jmp 	.loopY
	
	.drawLoopSetup:
	mov 	edx,ecx
	imul 	edx,4
	
	.drawLoop:
	add 	edi,edx
	mov 	ecx,eax
	
	rep 	movsd
	
	add 	edi, ebp
	
	dec 	ebx
	
	cmp 	ebx,0
	jne 	.drawLoop
	
	pop 	esp
	pop 	ebp
	pop 	edi
	pop 	esi
	pop 	edx
	pop 	ecx
	pop 	ebx
	pop 	eax
	
	ret

; INPUT	 : -
; OUTPUT : szines paletta betoltese
loadColorPalette:
	pusha
	
	mov 	eax, fileColorPalette
	mov 	ebx,0
	call 	fio_open
	mov 	ebx, colorPalette
	mov 	ecx, 1024
	call 	fio_read
	call 	fio_close
	popa
	
	ret

	
section .data
	width 						dd 		0
	height						dd 		0

	; current BMP Image size
	imageWidth					dd 		0
	imageHeight					dd 		0
	
	; Window size
	windowWidth 				dd 		0
	windowHeight 				dd 		0
	
	; Drawing
	bitmapOffset 				dd 		0 ; bitmap starting point
	paddingSize 				dd 		0 ; empty space
	
	; Necesary files to load images and colorPalette
	fileIconCrop				db 		'crop.bmp',0
	fileIconGauss				db		'GaussBlur.bmp',0
	fileIconResize 				db 		'resize.bmp',0
	fileIconSave 				db 		'save.bmp',0
	fileIconSaveCompressed 		db 		'saveCompressed.bmp',0
	fileIconSave8 				db 		'save8.bmp',0
	fileIconSave8Compressed 	db 		'save8Compressed.bmp',0
	
	fileColorPalette 			db 		'colorPalette.hex',0
	
	; Current Image pointers
	bmpImage					dd 		0
	bmpImageDrawn 				dd 		0
	bmpFile 					dd 		0
	depth 						dd 		0
	
	; Title
	windowText					dd 		'BMP Editor',0
	
	; Crop function coordinates + bool value for mouse
	crop_x0						dd 		0
	crop_y0 					dd 		0
	crop_x1						dd 		0
	crop_y1 					dd 		0
	cropOn 						db 		0	

	; Resize function coordinates + bool value for mouse
	resize_x					dd 		0
	resize_y					dd 		0
	resizeOn					db 		0
	
	; Strings
	newString 					db 		'New file name: ',0
	
	; GaussBlur
	gaussKernelTopBottom 		dd 		0.08203125, 0.12109375, 0.08203125		
	gaussKernelMiddle 			dd 		0.12109375, 0.1875, 0.12109375	
	; Bottom == Top
	;  _        _
	; | 21 31 21 |
	; | 31 48 21 |* 1/256
	; | 21 31 21 |
	;
	
	zero 						dd 		0.0

section .bss
	colorPalette 				resd 		256
	bmpHeader 					resb 		14 ; adatok 
	bitmapinfoheader 			resb 		40 ; DIB Header
	; foglalt memoria a mit hasznalok kulonbozo muveleteken keresztul a bmp adatai tarolasara
	fileBuffer 					resb 		40000000 ; file beolvasasara van
	imageBuffer 				resb 		40000000 ; bitmap
	finalBuffer 				resb 		40000000 ; meret + bitmap
	compressBuffer 				resb 		40000000 ; tomoritett
	
	; bitmap a gombokra
	bmpCrop						resb 		25000
	bmpGauss 					resb 		25000
	bmpResize 					resb 		25000
	bmpSave						resb 		25000
	bmpSave8					resb 		25000
	bmpSaveCompressed			resb 		25000
	bmpSave8Compressed			resb 		25000
	
	; mentesnel itt lesz tarolva a beirt uj file neve
	filename 					resb 		256

	; resize-ra hasznalt tombok (interpolaciora)
	interpolation_index_row 	resd 		3000
	interpolation_index_column 	resd 		3000
	