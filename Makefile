l42: main.o dbdatabase.o

main.o: main.c db.h dbdatabase.h
	gcc -g -c main.c

dbdatabase.o: dbdatabase.c dbdatabase.h
	gcc -g -c dbdatabase.c

dbdatabase.c: dbdatabase.h

dbdatabase.h: Database.dd dbtypedef.h
	datadraw Database.dd

clean:
	rm -f *.o *database.[ch] l42
