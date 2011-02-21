#include "db.h"

// Create a module, and it's block.
dbModule dbModuleCreate(
    utSym name,
    utSym prefix)
{
    dbModule module = dbModuleAlloc();
    dbBlock block = dbBlockAlloc();

    dbModuleSetSym(module, name);
    dbModuleSetPrefixSym(module, prefix);
    dbRootAppendModule(dbTheRoot, module);
    dbModuleAppendBlock(module, block);
    dbModuleSetTopBlock(module, block);
    return module;
}
