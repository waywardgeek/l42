#include "dbdatabase.h"

// Module methods
dbModule dbModuleCreate(utSym name, utSym prefix);

// Statement methods
dbStatement dbParseStatement(dbBlock block, char *text);
bool dbStatementExecutable(dbStatement statement);

// Shared library methods
bool dbSharedlibExecuteFunction(dbSharedlib sharedlib, char *functionName, int argc, char **argv);

// Compiler
dbSharedlib dbCompileStatement(dbStatement statement);

// Reader/writer
char *dbReadText(bool interactive);
extern bool dbInteractiveMode;

extern dbRoot dbTheRoot;
