#include <stdio.h>
#include "db.h"

// The read-compile-run loop.
static void readCompileRunLoop(void)
{
    dbModule interactiveModule = dbModuleCreate("Interactive", NULL);
    dbBlock block = dbModuleGetTopBlock(interactiveModule);
    dbStatement statement;
    dbSharedlib sharedlib;
    dbVariable returnValue;
    char *text;

    while(1) {
        text = readText();
        statement = dbParseStatement(block, text);
        if(dbStatementExecutable(statement)) {
            sharedlib = dbCompileStatement(statement);
            returnValue = dbExecuteLibraryFunction(sharedLib, "main", 0, NULL);
            if(returnValue != dbVariableNull) {
                dbVariableDestroy(returnValue);
            }
            dbFinstDestroy(finst);
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
