format ELF executable 3
entry start

segment readable writeable
    buffer      rb 5000 ; Buffer for incoming request
    filebuf     rb 8000 ; Buffer for the response file
    filename    rb 50  ; Buffer for the file name including path
    itoa_buf    rb 11  ; Buffer for converting number to string

    http_header_html db 'HTTP/1.1 200 OK',13,10,\
                         'Content-Type: text/html',13,10,\
                         'Connection: close',13,10,13,10
    header_len_html = $ - http_header_html

    http_header_ico db 'HTTP/1.1 200 OK',13,10,\
                        'Content-Type: image/x-icon',13,10,\
                        'Connection: close',13,10,13,10
    header_len_ico = $ - http_header_ico

    http_header_css db 'HTTP/1.1 200 OK',13,10,\
                        'Content-Type: text/css',13,10,\
                        'Connection: close',13,10,13,10
    header_len_css = $ - http_header_css

    http_header_woff db 'HTTP/1.1 200 OK',13,10,\
                         'Content-Type: font/woff2',13,10,\
                         'Connection: close',13,10,13,10
    header_len_woff = $ - http_header_woff

    log_index_prefix db 'Sent: index.html at '
    log_index_prefix_len = $ - log_index_prefix

    log_favicon_prefix db 'Sent: favicon.ico at '
    log_favicon_prefix_len = $ - log_favicon_prefix

    log_css_prefix db 'Sent: styles.css at '
    log_css_prefix_len = $ - log_css_prefix

    log_font_prefix db 'Sent: font.woff2 at '
    log_font_prefix_len = $ - log_font_prefix

    log_nl db 10

    sockfd   dd 0
    clientfd dd 0
    filefd   dd 0
    filelen  dd 0

    sockaddr:
        dw 2
        dw 0x991f
        dd 0
        rb 8

    socket_args:
        dd 2
        dd 1
        dd 0

    bind_args:
        dd 0
        dd sockaddr
        dd 16

    listen_args:
        dd 0

    accept_args:
        dd 0
        dd 0
        dd 0

segment readable executable
start:
    mov eax, 48
    mov ebx, 13
    mov ecx, 1
    int 0x80

    mov eax, 102
    mov ebx, 1
    mov ecx, socket_args
    int 0x80
    mov [sockfd], eax

    mov esi, eax
    mov [bind_args], esi
    mov [listen_args], esi
    mov [accept_args], esi

    mov eax, 102
    mov ebx, 2
    mov ecx, bind_args
    int 0x80

    mov eax, 102
    mov ebx, 4
    mov ecx, listen_args
    int 0x80

.accept_loop:
    mov eax, 102
    mov ebx, 5
    mov ecx, accept_args
    int 0x80
    mov [clientfd], eax

    mov eax, 3
    mov ebx, [clientfd]
    mov ecx, buffer
    mov edx, 5000 ; Size of buffer for incoming request
    int 0x80

    mov esi, buffer
    mov edi, css_str
    mov ecx, 5000 ; Size of request buffer (common for all paths)
.find_css:
    push ecx
    push esi
    push edi
    mov ecx, css_str_len
    repe cmpsb
    pop edi
    pop esi
    pop ecx
    je .use_css
    inc esi
    loop .find_css

    mov esi, buffer
    mov edi, favicon_str
    mov ecx, 5000 ; Size of request buffer (common for all paths)
.find_favicon:
    push ecx
    push esi
    push edi
    mov ecx, favicon_str_len
    repe cmpsb
    pop edi
    pop esi
    pop ecx
    je .use_favicon
    inc esi
    loop .find_favicon

    mov esi, buffer
    mov edi, font_str
    mov ecx, 5000 ; Size of request buffer (common for all paths)
.find_font:
    push ecx
    push esi
    push edi
    mov ecx, font_str_len
    repe cmpsb
    pop edi
    pop esi
    pop ecx
    je .use_font
    inc esi
    loop .find_font

.use_index:
    mov edi, filename
    mov esi, index_file
    mov ecx, index_file_len
    rep movsb
    mov byte [edi], 0
    jmp .log_index

.use_favicon:
    mov edi, filename
    mov esi, favicon_file
    mov ecx, favicon_file_len
    rep movsb
    mov byte [edi], 0
    jmp .log_favicon

.use_css:
    mov edi, filename
    mov esi, css_file
    mov ecx, css_file_len
    rep movsb
    mov byte [edi], 0
    jmp .log_css

.use_font:
    mov edi, filename
    mov esi, font_file
    mov ecx, font_file_len
    rep movsb
    mov byte [edi], 0
    jmp .log_font

.log_index:
    mov eax, 4
    mov ebx, 1
    mov ecx, log_index_prefix
    mov edx, log_index_prefix_len
    int 0x80
    jmp .log_time

.log_favicon:
    mov eax, 4
    mov ebx, 1
    mov ecx, log_favicon_prefix
    mov edx, log_favicon_prefix_len
    int 0x80
    jmp .log_time

.log_css:
    mov eax, 4
    mov ebx, 1
    mov ecx, log_css_prefix
    mov edx, log_css_prefix_len
    int 0x80
    jmp .log_time

.log_font:
    mov eax, 4
    mov ebx, 1
    mov ecx, log_font_prefix
    mov edx, log_font_prefix_len
    int 0x80
    jmp .log_time

.log_time:
    mov eax, 13
    xor ebx, ebx
    int 0x80

    push eax
    call itoa
    add esp, 4

    mov eax, 4
    mov ebx, 1
    mov ecx, edi
    mov edx, itoa_buf + 10
    sub edx, ecx
    int 0x80

    mov eax, 4
    mov ebx, 1
    mov ecx, log_nl
    mov edx, 1
    int 0x80

    jmp .send_file

.send_file:
    mov eax, 5
    mov ebx, filename
    xor ecx, ecx
    int 0x80
    mov [filefd], eax
    cmp eax, 0
    jl .close_client

    mov eax, 3
    mov ebx, [filefd]
    mov ecx, filebuf
    mov edx, 8000 ; Size of buffer for the response file
    int 0x80
    mov [filelen], eax

    mov eax, 6
    mov ebx, [filefd]
    int 0x80

    mov eax, 4
    mov ebx, [clientfd]

    mov esi, filename
    mov edi, favicon_file
    mov ecx, favicon_file_len
    cld
    repe cmpsb
    je .write_ico_header

    mov esi, filename
    mov edi, css_file
    mov ecx, css_file_len
    cld
    repe cmpsb
    je .write_css_header

    mov esi, filename
    mov edi, font_file
    mov ecx, font_file_len
    cld
    repe cmpsb
    je .write_woff_header

    mov ecx, http_header_html
    mov edx, header_len_html
    jmp .write_header

.write_ico_header:
    mov ecx, http_header_ico
    mov edx, header_len_ico
    jmp .write_header

.write_css_header:
    mov ecx, http_header_css
    mov edx, header_len_css
    jmp .write_header

.write_woff_header:
    mov ecx, http_header_woff
    mov edx, header_len_woff
    jmp .write_header

.write_header:
    int 0x80

    mov eax, 4
    mov ebx, [clientfd]
    mov ecx, filebuf
    mov edx, [filelen]
    int 0x80

    jmp .close_client

.close_client:
    mov eax, 6
    mov ebx, [clientfd]
    int 0x80

    jmp .accept_loop

itoa:
    mov ecx, 10
    mov edi, itoa_buf + 10 ; pointer to end of buffer
    mov byte [edi], 0
.itoa_loop:
    xor edx, edx
    div ecx
    dec edi
    add dl, '0'
    mov [edi], dl
    test eax, eax
    jnz .itoa_loop
    mov eax, edi
    ret

segment readable
favicon_str db 'GET /favicon.ico ' ; path on site: /favicon.ico
favicon_str_len = $ - favicon_str

css_str db 'GET /styles.css ' ; path on site: /styles.css
css_str_len = $ - css_str

font_str db 'GET /font.woff2 ' ; path on site: /font.woff2
font_str_len = $ - font_str

favicon_file db 'static/favicon.ico' ; path on server: static/favicon.ico
favicon_file_len = $ - favicon_file

css_file db 'static/styles.css' ; path on server: static/styles.css
css_file_len = $ - css_file

font_file db 'static/font.woff2' ; path on server: static/font.woff2
font_file_len = $ - font_file

index_file db 'index.html'  ; path on server: index.html
index_file_len = $ - index_file