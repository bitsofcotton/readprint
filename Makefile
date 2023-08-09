PROG=	LoaderI386

VERSION=	1m

CC=		gcc
CXX=		g++
AS=		gcc
LD=		gcc

BINMODE=	644
CFLAGS=		-Wall
CXXFLAGS=	${CFLAGS}
ASFLAGS=	${CFLAGS}
LDFLAGS=	-nostartfiles -nodefaultlibs -nostdlib
NOSHARED=	YES

CLEANFILES=	*~ *.o *.out *.bin

all:

clean:
	@rm -f ${CLEANFILES}
