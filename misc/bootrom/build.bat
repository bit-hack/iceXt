.\VC152\CL.EXE /AT /G2 /Gs /Gx /c /Zl *.cpp
.\VC152\ML.EXE /AT /c *.asm 
.\VC152\LINK.EXE /TINY /NODEFAULTLIBRARYSEARCH entry.obj main.obj, out.com,,,,

set /p DUMMY=Hit ENTER to continue...

mkdir output
move /Y *.com output
move /Y *.map output

nasm\ndisasm.exe output\out.com > output\out.dis

mkdir temp
move /Y *.obj temp

python tohex.py output/out.com
