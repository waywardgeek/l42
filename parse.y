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

%{

#include "db.h"

dbModule dbCurrentModule;
static dbEnum dbCurrentEnum;
static dbClass dbCurrentClass;
static dbUnion dbCurrentUnion;
static dbVariable dbCurrentVariable;
static dbRelationship dbCurrentRelationship;
static dbKey dbCurrentKey;
static uint32 dbCurrentEnumValue;
static uint8 dbIntWidth;
static uint32 dbUnionNumber;

/*--------------------------------------------------------------------------------------------------
  Provide yyerror function capability.
--------------------------------------------------------------------------------------------------*/
void dberror(
    char *message,
    ...)
{
    char *buff;
    va_list ap;

    va_start(ap, message);
    buff = utVsprintf(message, ap);
    va_end(ap);
    utError("Line %d, token \"%s\": %s", dbLineNum, dblextext, buff);
}

/*--------------------------------------------------------------------------------------------------
  Build a user-defined type variable, either an enum or class.
--------------------------------------------------------------------------------------------------*/
static dbVariable buildUserTypeVariable(
    dbModule module,
    utSym typeSym,
    utSym sym)
{
    dbVariable variable = dbVariableCreate(dbCurrentClass, dbCurrentUnion, P
%token KWBIT
%token KWBOOL
%token KWCASCADE
%token KWCHAR
%token KWCHILD_ONLY
%token KWCLASS
%token KWCREATE_ONLY
%token KWDOUBLE
%token KWDOUBLY_LINKED
%token KWEND
%token KWENUM
%token KWFLOAT
%token KWFREE_LIST
%token KWHASHED
%token KWHEAP
%token KWIMPORT
%token KWINHERITANCE
%token KWLINKED_LIST
%token KWMANDATORY
%token KWMODULE
%token KWORDERED_LIST
%token KWPARENT_ONLY
%token KWPERSISTENT
%token KWREFERENCE_SIZE
%token KWRELATIONSHIP
%token KWSCHEMA
%token KWSPARSE
%token KWSYM
%token KWTAIL_LINKED
%token KWTYPEDEF
%token KWUNION
%token KWUNORDERED

%%

goal: initialize module
;

initialize: /* Empty */
{
    dbCurrentUnion = dbUnionNull;
}

module: moduleHeader '\n' moduleStuff
;

moduleHeader: KWMODULE upperIdent optIdent
{
    dbCurrentModule = dbModuleCreate($2, $3);
}
;

optIdent: /* Empty */
{
    $$ = utSymNull;
}
| IDENT
{
    $$ = $1;
}
;

moduleStuff: /* Empty */
| moduleStuff moduleElement
;

moduleElement: import
| enum
| typedef
| class
| value
| relationship
;

import: KWIMPORT upperIdent '\n'
{
//TODO: Create import statement here
}
;

enum: enumHeader KWBEGIN entries KWEND
;

enumHeader: KWENUM upperIdent optIdent '\n'
{
    dbCurrentEnum = dbEnumCreate(dbCurrentModule, $2, $3);
    dbCurrentEnumValue = 0;
}
;

entries: entry
| entries entry
;

entry: IDENT '\n'
{
    dbEntryCreate(dbCurrentEnum, $1, dbCurrentEnumValue);
    dbCurrentEnumValue++;
}
| IDENT '=' INTEGER '\n'
{
    dbCurrentEnumValue = $3;
    dbEntryCreate(dbCurrentEnum, $1, dbCurrentEnumValue);
    dbCurrentEnumValue++;
}
;

typedef: KWTYPEDEF IDENT '\n'
{
    dbTypedefCreate(dbCurrentModule, $2, "0");
}
| KWTYPEDEF IDENT '=' STRING '\n'
{
    dbTypedefCreate(dbCurrentModule, $2, utSymGetName($4));
}
;

class: classHeader classOptions '\n' KWBEGIN properties KWEND
| classHeader classOptions '\n'
;

classHeader: KWCLASS upperIdent optLabel
{
    dbClass baseClass = dbClassNull;
    dbModule baseModule = dbModuleNull;
    if($3 != utSymNull && dbLoadModules) {
        baseModule = dbRootFindModule(dbTheRoot, dbUpperSym($3));
        if(baseModule == dbModuleNull) {
            baseModule = dbFindModuleFromPrefix($3);
        }
        if(baseModule == dbModuleNull) {
            dberror("Undefined module %s", utSymGetName($3));
        }
        baseClass = dbModuleFindClass(baseModule, $2);
        if(baseClass == dbClassNull) {
            dberror("Base class %s not defined in module %s", utSymGetName($2), utSymGetName($3));
        }
    }
    dbCurrentClass = dbClassCreate(dbCurrentModule, $2, baseClass);
    dbClassSetBaseClassSym(dbCurrentClass, $3);
    dbUnionNumber = 1;
    dbCacheNumber = 1;
}
;

value: valueHeader '\n' KWBEGIN properties KWEND
;

valueHeader: KWVALUE upperIdent
{
    dbCurrentClass = dbClassCreate(dbCurrentModule, $2, baseClass);
    dbClassSetMemoryStyle(dbCurrentClass, MEM_VALUE);
    dbUnionNumber = 1;
}
;

classOptions: /* Empty */
| classOptions classOption
;

classOption: KWREFERENCE_SIZE INTEGER
{
    if($2 & 7 || $2 > 64 || $2 < 8) {
        dberror("Reference sizes may only be 8, 16, 32, or 64");
    }
    dbClassSetReferenceSize(dbCurrentClass, (uint8)$2);
}
| KWFREE_LIST
{
    dbClassSetMemoryStyle(dbCurrentClass, MEM_FREE_LIST);
}
| KWCREATE_ONLY
{
    dbClassSetMemoryStyle(dbCurrentClass, MEM_CREATE_ONLY);
}
;

properties: variable '\n'
| union
| properties variable '\n'
| properties union
;

variable: baseVariable variableAttributes
| KWARRAY baseVariable variableAttributes
{
    if(dbCurrentUnion != dbUnionNull) {
        dberror("Arrays are not allowed in unions");
    }
    dbVariableSetArray(dbCurrentVariable, true);
}
| KWARRAY baseVariable INDEX variableAttributes
{
    char *index;
    if(dbCurrentUnion != dbUnionNull) {
        dberror("Arrays are not allowed in unions");
    }
    if(dbVariableSparse(dbCurrentVariable)) {
        dberror("Fixed sized arrays cannot be sparse");
    }
    dbVariableSetArray(dbCurrentVariable, true);
    dbVariableSetFixedSize(dbCurrentVariable, true);
    index = utSymGetName($3);
    dbVariableSetIndex(dbCurrentVariable, index, strlen(index) + 1);
}
;

variableAttributes: /* Empty */
| variableAttributes variableAttribute
;

variableAttribute: KWCASCADE
{
    dbVariableSetCascade(dbCurrentVariable, true);
}
| KWVIEW
{
    dbVariableSetView(dbCurrentVariable, true);
}
| KWSPARSE
{
    if(dbCurrentUnion != dbUnionNull) {
        dberror("Union fields cannot be sparse");
    }
    dbVariableSetSparse(dbCurrentVariable, true);
}
| '=' STRING
{
    char *value = utSymGetName($2);
    dbVariableSetInitializer(dbCurrentVariable, value, strlen(value) + 1);
}
;

baseVariable: IDENT upperIdent
{
    dbCurrentVariable = buildUserTypeVariable(dbCurrentModule, $1, $2);
}
| moduleSpec IDENT upperIdent
{
    dbCurrentVariable = buildUserTypeVariable($1, $2, $3);
}
| variableType upperIdent
{
    dbCurrentVariable = dbVariableCreate(dbCurrentClass, dbCurrentUnion, $1, $2);
    if($1 == VAR_INT || $1 == VAR_UINT) {
        if(dbIntWidth != 8 && dbIntWidth != 16 && dbIntWidth != 32 && dbIntWidth != 64) {
            dberror("Valid integer widths are 8, 16, 32, and 64");
        }
        dbVariableSetWidth(dbCurrentVariable, dbIntWidth);
    }
}
;

cacheTogether: cacheTogetherHeader cacheIdents
;

cacheTogetherHeader: KWCACHE_TOGETHER
{
    if(!dbClassRedo(dbCurrentClass)) {
        dbCurrentCache = dbCacheCreate(dbCurrentClass);
        dbCacheSetLine(dbCurrentCache, dbLineNum);
        dbCacheSetNumber(dbCurrentCache, dbCacheNumber);
        dbCacheNumber++;
    }
}

cacheIdents: /* Empty */
| cacheIdents upperIdent
{
    if(!dbClassRedo(dbCurrentClass)) {
        dbPropident propident = dbPropidentAlloc();
        dbPropidentSetSym(propident, $2);
        dbCacheAppendPropident(dbCurrentCache, propident);
    }
}
;

moduleSpec: IDENT ':'
{
    dbModule module = dbRootFindModule(dbTheRoot, $1);
    if(module == dbModuleNull) {
        module = dbFindModuleFromPrefix($1);
    }
    if(module == dbModuleNull && dbLoadModules) {
        dberror("Module %s not found", utSymGetName($1));
    }
    $$ = module;
}

variableType: INTTYPE
{
    dbIntWidth = (uint8)$1;
    $$ = VAR_INT;
}
| UINTTYPE
{
    dbIntWidth = (uint8)$1;
    $$ = VAR_UINT;
}
| KWFLOAT
{
    $$ = VAR_FLOAT;
}
| KWDOUBLE
{
    $$ = VAR_DOUBLE;
}
| KWBIT
{
    if(dbCurrentUnion == dbUnionNull) {
        $$ = VAR_BIT;
    } else {
        $$ = VAR_BOOL;
    }
}
| KWBOOL
{
    $$ = VAR_BOOL;
}
| KWCHAR
{
    $$ = VAR_CHAR;
}
| KWENUM
{
    $$ = VAR_ENUM;
}
| KWTYPEDEF
{
    $$ = VAR_TYPEDEF;
}
| KWSYM
{
    $$ = VAR_SYM;
}
;

union: unionHeader KWBEGIN nonUnionVariables KWEND
{
    if(dbUnionGetFirstVariable(dbCurrentUnion) == dbVariableNull) {
        dbUnionDestroy(dbCurrentUnion);
    }
    dbCurrentUnion = dbUnionNull;
}
;

unionHeader: KWUNION upperIdent '\n'
{
    dbCurrentUnion = dbUnionCreate(dbCurrentClass, $2, dbUnionNumber++);
}
;

nonUnionVariables: variable ':' unionCases '\n'
| nonUnionVariables variable ':' unionCases '\n'
;

unionCases: unionCase
| unionCases unionCase
;

unionCase: IDENT
{
    dbCase theCase = dbCaseAlloc();
    dbCaseSetEntrySym(theCase, $1);
    dbVariableAppendCase(dbCurrentVariable, theCase);
}

relationship: relationshipHeader relationshipType relationshipOptions '\n'
{
    dbRelationshipSetType(dbCurrentRelationship, $2);
}
;

relationshipHeader: KWRELATIONSHIP upperIdent optLabel upperIdent optLabel
{
    dbClass parent = dbModuleFindClass(dbCurrentModule, $2);
    dbClass child = dbModuleFindClass(dbCurrentModule, $4);
    if(parent == dbClassNull) {
        dberror("Unknown class %s", utSymGetName($2));
    }
    if(child == dbClassNull) {
        dberror("Unknown class %s", utSymGetName($4));
    }
    if(dbCurrentSchema == dbSchemaNull) {
        dbCurrentSchema = dbSchemaCreate(dbCurrentModule, dbModuleGetSym(dbCurrentModule));
    }
    /* Note that the type is just a place-holder.  We fill in the real type after parsing the type */
    dbCurrentRelationship = dbRelationshipCreate(dbCurrentSchema, parent, child, REL_UNBOUND,
        dbUpperSym($3), dbUpperSym($5));
}
;

optLabel: /* Empty */
{
    $$ = utSymNull;
}
| ':' IDENT
{
    $$ = $2;
}
;

relationshipOptions: /* Empty */
| relationshipOptions relationshipOption
;

relationshipType: /* Empty */
{
    $$ = REL_POINTER;
}
| KWLINKED_LIST
{
    $$ = REL_LINKED_LIST;
}
| KWDOUBLY_LINKED
{
    $$ = REL_DOUBLY_LINKED;
}
| KWTAIL_LINKED
{
    $$ = REL_TAIL_LINKED;
}
| KWARRAY
{
    $$ = REL_ARRAY;
}
| KWHEAP key
{
    $$ = REL_HEAP;
}
| KWHASHED key
{
    $$ = REL_HASHED;
    if(dbRelationshipGetFirstKey(dbCurrentRelationship) == dbKeyNull) {
        dbAddDefaultKey(dbCurrentRelationship);
    }
}
| KWORDERED_LIST key
{
    $$ = REL_ORDERED_LIST;
}
;

key: /* empty */
| key keyproperties
;

keyproperties : upperIdent
{
    dbCurrentKey = dbUnboundKeyCreate(dbCurrentRelationship, $1, dbLineNum);
}
| keyproperties '.' upperIdent
{
    dbUnboundKeyvariableCreate(dbCurrentKey, $3);
}
;

relationshipOption: KWCASCADE
{
    dbRelationshipSetCascade(dbCurrentRelationship, true);
}
| KWMANDATORY
{
    dbRelationshipSetMandatory(dbCurrentRelationship, true);
    dbRelationshipSetCascade(dbCurrentRelationship, true);
}
| KWPARENT_ONLY
{
    dbRelationshipSetAccessChild(dbCurrentRelationship, false);
}
| KWCHILD_ONLY
{
    dbRelationshipSetAccessParent(dbCurrentRelationship, false);
}
| KWSPARSE
{
    dbRelationshipSetSparse(dbCurrentRelationship, true);
}
| KWUNORDERED
{
    dbRelationshipSetUnordered(dbCurrentRelationship, true);
}
;

upperIdent: IDENT
{
    $$ = dbUpperSym($1);
}

%%
