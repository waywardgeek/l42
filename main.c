#include <stdio.h>
#include "db.h"

// Read enough text to compile one statement.
static char *readText(void)
{
    return NULL; //temp: Do this
}

// The read-compile-run loop.
static void readCompileRunLoop(void)
{
    dbModule interactiveModule = dbModuleCreate("Interactive", NULL);
    dbBlock block = dbModuleGetTopBlock(interactiveModule);
    dbStatement statement;
    dbSharedlib sharedlib;
    char *text;

    while(1) {
        text = readText();
        statement = dbParseStatement(block, text);
        if(dbStatementExecutable(statement)) {
            sharedlib = dbCompileStatement(statement);
            dbExecuteLibraryFunction(sharedlib, "main", 0, NULL);
            dbSharedlibDestroy(sharedlib);
        }
    }
}

int main(
    int argc,
    char *argv[])
{
    readCompileRunLoop();
    return 0;
}
