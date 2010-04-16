m4 -E <templates/flasher_version.h.m4 >flasher_version.h.tmp
cmp -s flasher_version.h.tmp flasher_version.h || copy flasher_version.h.tmp flasher_version.h
pause