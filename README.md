# helloworld-gui-nasm
https://gaultier.github.io/blog/x11_x64.html

nasm -f elf64 -g main.nasm && ld main.o -static -o main
./main; echo $?