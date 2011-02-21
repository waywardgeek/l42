/*
 * Copyright (C) 2006, 2011 Bill Cox
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License 
 * along with this program; if not, write to the Free Software 
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA
 */

#include "db.h"

extern bool dbInteractiveMode;

// Read enough text to compile one statement.  Only statements that start with a
// recognized keyword can have sub-blocks.  Multi-line statements are terminated
// with a blank line in interactive mode.
char *dbReadText(
    bool interactive)
{
    dbInteractiveMode = true;
    //TODO: do this
}

#include <ctype.h>
#include "db.h"

FILE *dbFile;
uint32 dbLineNum;
bool dbLoadModules;

/* Remember not to have any static variables!  dbReadFile is recursive! */

/*--------------------------------------------------------------------------------------------------
  Bind the variable type.
--------------------------------------------------------------------------------------------------*/
void dbBindVariable(
    dbVariable variable,
    dbModule module)
{
    utSym typeSym = dbVariableGetTypeSym(variable);
    dbClass pointerClass = dbModuleFindClass(module, typeSym);
    dbEnum theEnum;
    dbTypedef theTypedef;

    if(pointerClass != dbClassNull) {
        dbVariableSetType(variable, VAR_POINTER);
        dbVariableSetClassProp(variable, pointerClass);
        return;
    }
    theEnum = dbModuleFindEnum(module, typeSym);
    if(theEnum != dbEnumNull) {
        dbVariableSetType(variable, VAR_ENUM);
        dbVariableSetEnumProp(variable, theEnum);
        return;
    }
    theTypedef = dbModuleFindTypedef(module, typeSym);
    if(theTypedef == dbTypedefNull) {
        utError("Line %u: Undefined type %s.%s", dbVariableGetLine(variable),
            dbModuleGetName(module), utSymGetName(typeSym));
    }
    dbVariableSetType(variable, VAR_TYPEDEF);
    dbVariableSetTypedefProp(variable, theTypedef);
}

/*--------------------------------------------------------------------------------------------------
  Bind all variable types in the module.
--------------------------------------------------------------------------------------------------*/
static void bindUnion(
    dbUnion theUnion)
{
    dbClass theClass = dbUnionGetClass(theUnion);
    dbEnum theEnum;
    dbEntry entry;
    utSym variableSym = dbUnionGetVariableSym(theUnion);
    dbVariable variable = dbClassFindVariable(theClass, variableSym);
    dbCase theCase;

    if(variable == dbVariableNull) {
        utError("Line %u: Undefined variable %s", dbUnionGetLine(theUnion),
            utSymGetName(variableSym));
    }
    if(dbVariableGetType(variable) != VAR_ENUM) {
        utError("Line %u: Expected enum variable rather than %s", dbUnionGetLine(theUnion),
            utSymGetName(variableSym));
    }
    dbUnionSetTypeVariable(theUnion, variable);
    theEnum = dbVariableGetEnumProp(variable);
    dbForeachUnionVariable(theUnion, variable) {
        dbForeachVariableCase(variable, theCase) {
            entry = dbEnumFindEntry(theEnum, dbCaseGetEntrySym(theCase));
            if(entry == dbEntryNull) {
                utError("Line %u: Unknown entry %s", dbVariableGetLine(variable),
                    utSymGetName(dbCaseGetEntrySym(theCase)));
            }
            dbEntryAppendCase(entry, theCase);
        } dbEndVariableCase;
    } dbEndUnionVariable;
}

/*--------------------------------------------------------------------------------------------------
  Bind all variable types in the module.
--------------------------------------------------------------------------------------------------*/
void dbBindTypes(
    dbModule module)
{
    dbUnion theUnion;
    dbClass theClass;
    dbVariable variable;
    dbVariableType type;

    dbForeachModuleClass(module, theClass) {
        dbForeachClassVariable(theClass, variable) {
            type = dbVariableGetType(variable);
            if(type == VAR_UNBOUND) {
                dbBindVariable(variable, module);
            }
            if(dbVariableGetType(variable) != VAR_POINTER && dbVariableCascade(variable)) {
                utError("Line %u: Only pointer variables can be cascade",
                    dbVariableGetLine(variable));
            }
        } dbEndClassVariable;
        dbForeachClassUnion(theClass, theUnion) {
            bindUnion(theUnion);
        } dbEndClassUnion;
    } dbEndModuleClass;
}

/*--------------------------------------------------------------------------------------------------
  Just read one line from the input file.
--------------------------------------------------------------------------------------------------*/
static bool readLine(
    FILE *inFile,
    char **lineBufferPtr,
    uint32 *bufferSizePtr)
{
    char *lineBuffer = *lineBufferPtr;
    uint32 bufferSize = *bufferSizePtr;
    uint32 bufferLength = 0;
    int c;

    utDo {
        c = getc(inFile);
    } utWhile(c != EOF && c != '\n') {
        if(c != '\r') {
            if(bufferLength == bufferSize) {
                bufferSize <<= 1;
                utResizeArray(lineBuffer, bufferSize);
            }
            lineBuffer[bufferLength++] = c;
        }
    } utRepeat;
    if(bufferLength == bufferSize) {
        bufferSize <<= 1;
        utResizeArray(lineBuffer, bufferSize);
    }
    lineBuffer[bufferLength] = '\0';
    *lineBufferPtr = lineBuffer;
    *bufferSizePtr = bufferSize;
    return c != EOF || bufferLength > 0;
}

/*--------------------------------------------------------------------------------------------------
  Find the module in the module path.  Return the file name.
--------------------------------------------------------------------------------------------------*/
static char *findModuleFileInModpath(
    char *moduleName)
{
    dbModpath modpath;
    char *fileName;

    dbForeachRootModpath(dbTheRoot, modpath) {
        fileName = utSprintf("%s%c%s.dd", dbModpathGetName(modpath), UTDIRSEP, moduleName);
        if(utFileExists(fileName)) {
            return fileName;
        }
    } dbEndRootModpath;
    return NULL;
}

/*--------------------------------------------------------------------------------------------------
  Find the first letter after the identifier.
--------------------------------------------------------------------------------------------------*/
static char *findIdentifierEnd(
    char *identPtr)
{
    int c;

    utDo {
        c = *identPtr;
    } utWhile(isalnum(c) || c == '_') {
        identPtr++;
    } utRepeat;
    return identPtr;
}

/*--------------------------------------------------------------------------------------------------
  Check the current line to see if it's an import statement.
--------------------------------------------------------------------------------------------------*/
static void checkForModuleImport(
    char *lineBuffer)
{
    utSym moduleSym;
    char *moduleName, *fileName, *end;
    uint32 linePosition = 6;
    int c;

    if(strncmp(lineBuffer, "import", 6)) {
        return;
    }
    utDo {
        c = lineBuffer[linePosition];
    } utWhile(c == ' ' || c == '\t') {
        linePosition++;
    } utRepeat;
    moduleName = lineBuffer + linePosition;
    end = findIdentifierEnd(moduleName);
    *end = '\0';
    moduleSym = utSymCreate(moduleName);
    if(dbRootFindModule(dbTheRoot, moduleSym) != dbModuleNull) {
        /* Already loaded the module. */
        return;
    }
    fileName = findModuleFileInModpath(moduleName);
    if(fileName == NULL) {
        utError("Unable to find module %s in the module path", moduleName);
    }
    dbReadFile(fileName, true);
}

/*--------------------------------------------------------------------------------------------------
  Just scan the file once, looking for import statements.  Load the imported modules.
--------------------------------------------------------------------------------------------------*/
static void loadImportedModules(
    char *fileName)
{
    uint32 bufferSize = 256;
    char *lineBuffer = utNewA(char, bufferSize);
    FILE *inFile = fopen(fileName, "r");

    if(!inFile) {
        utExit("Could not open file %s for reading", fileName);
    }
    while(readLine(inFile, &lineBuffer, &bufferSize)) {
        checkForModuleImport(lineBuffer);
    }
    utFree(lineBuffer);
    fclose(inFile);
}

/*--------------------------------------------------------------------------------------------------
  Read a DataDraw file.  Note that this function is recursive due to "import" statements!  No
  static data!
--------------------------------------------------------------------------------------------------*/
bool dbReadFile(
    char *fileName,
    bool loadModules)
{
    fileName = utAllocString(fileName);
    if(loadModules) {
        loadImportedModules(fileName);
    }
    utLogMessage("Reading DataDraw file %s", fileName);
    dbFile = fopen(fileName, "r");
    if(!dbFile) {
        utExit("Could not open file %s for reading", fileName);
    }
    utFree(fileName);
    dbLineNum = 1;
    dbLoadModules = loadModules;
    dbLastWasReturn = true;
    dbEnding = false;
    if(dbparse()) {
        fclose(dbFile);
        return false;
    }
    if(dbLoadModules) {
        dbBindTypes(dbCurrentModule);
    }
    fclose(dbFile);
    return true;
}

