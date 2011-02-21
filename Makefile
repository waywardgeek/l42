CFLAGS=-Wall -g -c -DDD_DEBUG
#CFLAGS=-Wall -O2 -c
LFLAGS= -g

SOURCE=main.c \
dbdatabase.c \
module.c \
read.c

OBJS=$(patsubst %.c,%.o,$(SOURCE))

all: l42

l42: depends $(OBJS)
	gcc $(LFLAGS) -DDD_DEBUG -o l42 $(OBJS) -lddutil-dbg

depends: dbdatabase.h dbdatabase.c
	gcc -MM $(CFLAGS) $(SOURCE) > depends

clean:
	rm -f *.o *database.[ch] l42 depends

dbdatabase.c: dbdatabase.h

dbdatabase.h: Database.dd
	datadraw Database.dd

-include depends
