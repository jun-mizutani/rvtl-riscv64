# Makefile for rvtl64 - RISC-V
#     2025/07/28  Jun Mizutani

INSTALLDIR = /usr/bin/

SOURCE_FULL = debug.s ext.s mt19937ar.s signal.s syscalls.s vtlfb.s vtlsys.s \
         errorno.s fblib.s rvtl64.s stdio.s syserror.s vtllib.s

SOURCE = debug.s ext.s mt19937ar.s signal.s syscalls.s vtlsys.s \
         errorno.s rvtl64.s stdio.s syserror.s vtllib.s

# self assemble
ARCH=

AS=${ARCH}as
LD=${ARCH}ld
STRIP=${ARCH}strip

all : rvtl

rvtls : ${SOURCE}
	${AS} -o rvtl64.o rvtl64.s --defsym SMALL_VTL=1
	${LD} --no-relax -o rvtl64 rvtl64.o
	${STRIP} rvtl64

rvtl : ${SOURCE}
	${AS} -o rvtl64.o rvtl64.s
	${LD} -o rvtl64 rvtl64.o
	${STRIP} rvtl64

nostrip : ${SOURCE}
	${AS} -o rvtl64.o rvtl64.s
	${LD} -o rvtl64 rvtl64.o

debug : ${SOURCE}
	${AS} -o rvtl64.o rvtl64.s --defsym DEBUG=1
	${LD} -o rvtl64 rvtl64.o

install :
	cp rvtl64 ${INSTALLDIR}

uninstall :
	rm ${INSTALLDIR}rvtl64

dist :
	rm *.o
	mv rvtl64 ..

clean :
	rm *.o rvtl64

lines : 
	wc -l ${SOURCE}
