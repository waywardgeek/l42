#include <stdio.h>
#include "db.h"

dbRoot dbTheRoot;

// The read-compile-run loop.
static void readCompileRunLoop(void)
{
    dbModule interactiveModule = dbModuleCreate(utSymCreate("Interactive"), utSymNull);
    dbBlock block = dbModuleGetTopBlock(interactiveModule);
    dbStatement statement;
    dbSharedlib sharedlib;
    char *text;

    while(1) {
        text = dbReadText(true);
        statement = dbParseStatement(block, text);
        if(dbStatementExecutable(statement)) {
            sharedlib = dbCompileStatement(statement);
            dbSharedlibExecuteFunction(sharedlib, "main", 0, NULL);
            dbSharedlibDestroy(sharedlib);
        }
    }
}

int main(
    int argc,
    char *argv[])
{
    utStart();
    dbDatabaseStart();
    readCompileRunLoop();
    dbDatabaseStop();
    utStop(false);
    return 0;
}
