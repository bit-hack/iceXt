nasm\nasm.exe -f bin -l bin/diskrom.lst -o bin/diskrom.bin diskrom.asm
python tohex.py bin/diskrom.bin ../diskrom.hex
pause
