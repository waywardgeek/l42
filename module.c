#include "db.h"

// Create a module, and it's block.
dbModule dbModuleCreate(
    utSym name,
    utSym prefix)
{
    dbModule module = dbModuleAlloc();
    dbBlock block = dbBlockAlloc();

    dbModuleSetName(module, name);
    dbModuleSetPrefixSym(module, prefix);
    dbRootAppendMoule(dbTheRoot, module);
    dbModuleAppendBlock(module, block);
    dbModuleSetTopBlock(module, block);
    return module;
}
