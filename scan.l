/*
 * Copyright (C) 2006 Bill Cox
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

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include "db.h"
#include "dbparse.h"

#define YY_NEVER_INTERACTIVE 1
#define YY_INPUT(buf,result,max_size) \
    if((result = dbRead((char *) buf, max_size )) < 0 ) \
        YY_FATAL_ERROR( "input in flex scanner failed" );

bool dbLastWasReturn;
bool dbEnding;

static int dbRead(char *buf, int maxSize)
{
    int numChars = 0;
    int c;

    do {
        if(dbLastWasReturn) {
            /* Insert a tab in front of each line to force a character to match */
            c = '\t';
            dbLastWasReturn = false;
        } else if(dbEnding) {
            c = EOF;
        } else {
            c = getc(dbFile);
        }
        if(!dbEnding && c == EOF) {
            /* Add a newline at end of file in case the input file is missing it */
            c = '\n';
            dbEnding = true;
        }
        if(c != EOF && c != '\r') {
            *buf++ = c;
            numChars++;
            if(c == '\n') {
                dbLastWasReturn = true;
            }
        }
    } while(numChars < maxSize && c != EOF);
    return numChars;
}

static char *unmunge(
    char *string)
{
    char *buffer = utMakeString(strlen(string));
    char *p = buffer;

    string++; /* Skip " */
    while(*string != '\0') {
        if(*string == '\\') {
            string++;
        }
        *p++ = *string++;
    }
    *--p = '\0'; /* Overwrite terminating " */
    return buffer;
}

static uint16 findIndentDepth(char *string)
{
    uint16 length = 0;

    while(*string) {
        if(*string == ' ') {
            length++;
        } else if(*string == '\t') {
            length += 8;
        }
        string++;
    }
    return length;
}

int dblexwrap(void)
{
    return 1;
}

#ifdef DV_DEBUG
#define myDebug utDebug
#else
#define myDebug noDebug
#endif
#undef YYLMAX
#define YYLMAX 4096

static uint16 dbCommentDepth, dbIndentLevels = 0, dbIndentDepth[DV_MAX_INDENT] = {8};

static void noDebug(char *foo, ...) {}

%}

%option prefix="dblex"
%option outfile="lex.yy.c"

%Start comment

%%
<INITIAL>^[ \t]*"//".*\n        { dbLineNum++; myDebug("comment line\n"); } /* Single line comment */
<INITIAL>[ \t]*"//".*\n         { dbLineNum++; myDebug("newline\n"); return '\n'; } /* Tail comment */
<INITIAL>"/*"                   { myDebug("Start block comment...\n");
                                  dbCommentDepth = 1;
                                  BEGIN comment; }
<comment>"/*"                   { dbCommentDepth++; }
<comment>"*/"                   { myDebug("End block comment\n");
                                  dbCommentDepth--;
                                  if (dbCommentDepth == 0) {
                                     BEGIN INITIAL;
                                  } }
<comment>.                      ;
<comment>"\n"                   { dbLineNum++; }


<INITIAL>^[ \t]*\n              { dbLineNum++; }
<INITIAL>^[ \t]+                { uint16 length = findIndentDepth(dblextext);
                                  uint16 oldLevels = dbIndentLevels;
                                  if(length > dbIndentDepth[dbIndentLevels]) {
                                      dbIndentDepth[++dbIndentLevels] = length;
                                      myDebug("KWBEGIN\n");
                                      return KWBEGIN;
                                  } else if(length < dbIndentDepth[dbIndentLevels]) {
                                      while(dbIndentLevels > 0 &&
                                              length != dbIndentDepth[dbIndentLevels]) {
                                          dbIndentLevels--;
                                      }
                                      if(length != 8 && dbIndentLevels == 0) {
                                          dberror("Mismatched indentation");
                                      }
                                      if(dbIndentLevels + 1 != oldLevels) {
                                          dbNumEndsRemaining = oldLevels - dbIndentLevels - 1;
                                          myDebug("Starting multiple ends...\n");
                                      }
                                      myDebug("KWEND\n");
                                      return KWEND;
                                }}

<INITIAL>[ \t]+                 ;

<INITIAL>"array"                {myDebug("KWARRAY\n"); return KWARRAY;}
<INITIAL>"attributes"           {myDebug("KWATTRIBUTES\n"); return KWATTRIBUTES;}
<INITIAL>"bit"                  {myDebug("KWBIT\n"); return KWBIT;}
<INITIAL>"bool"                 {myDebug("KWBOOL\n"); return KWBOOL;}
<INITIAL>"cascade"              {myDebug("KWCASCADE\n"); return KWCASCADE;}
<INITIAL>"char"                 {myDebug("KWCHAR\n"); return KWCHAR;}
<INITIAL>"child_only"           {myDebug("KWCHILD_ONLY\n"); return KWCHILD_ONLY;}
<INITIAL>"class"                {myDebug("KWCLASS\n"); return KWCLASS;}
<INITIAL>"create_only"          {myDebug("KWCREATE_ONLY\n"); return KWCREATE_ONLY;}
<INITIAL>"double"               {myDebug("KWDOUBLE\n"); return KWDOUBLE;}
<INITIAL>"doubly_linked"        {myDebug("KWDOUBLY_LINKED\n"); return KWDOUBLY_LINKED;}
<INITIAL>"enum"                 {myDebug("KWENUM\n"); return KWENUM;}
<INITIAL>"float"                {myDebug("KWFLOAT\n"); return KWFLOAT;}
<INITIAL>"free_list"            {myDebug("KWFREE_LIST\n"); return KWFREE_LIST;}
<INITIAL>"hashed"               {myDebug("KWHASHED\n"); return KWHASHED;}
<INITIAL>"heap"                 {myDebug("KWHEAP\n"); return KWHEAP;}
<INITIAL>"import"               {myDebug("KIMPORT\n"); return KWIMPORT;}
<INITIAL>"linked_list"          {myDebug("KWLINKED_LIST\n"); return KWLINKED_LIST;}
<INITIAL>"mandatory"            {myDebug("KWMANDATORY\n"); return KWMANDATORY;}
<INITIAL>"module"               {myDebug("KWMODULE\n"); return KWMODULE;}
<INITIAL>"ordered_list"         {myDebug("KWORDERED_LIST\n"); return KWORDERED_LIST;}
<INITIAL>"parent_only"          {myDebug("KWPARENT_ONLY\n"); return KWPARENT_ONLY;}
<INITIAL>"reference_size"       {myDebug("KWREFERENCE_SIZE\n"); return KWREFERENCE_SIZE;}
<INITIAL>"relationship"         {myDebug("KWRELATIONSHIP\n"); return KWRELATIONSHIP;}
<INITIAL>"sym"                  {myDebug("KWSYM\n"); return KWSYM;}
<INITIAL>"tail_linked"          {myDebug("KWTAIL_LINKED\n"); return KWTAIL_LINKED;}
<INITIAL>"typedef"              {myDebug("KWTYPEDEF\n"); return KWTYPEDEF;}
<INITIAL>"union"                {myDebug("KWUNION\n"); return KWUNION;}
<INITIAL>"unordered"            {myDebug("KWUNORDERED\n"); return KWUNORDERED;}

<INITIAL>"."                    { myDebug(".\n"); return '.'; }
<INITIAL>"+"\n                  { myDebug("Line continuation\n"); dbLineNum++; }
<INITIAL>\n                     { myDebug("newline\n"); dbLineNum++; return '\n'; }
<INITIAL>[0-9]+                 { dblval.intVal = atol(dblextext);
                                  myDebug("INTEGER %u\n", dblval.intVal);
                                  return INTEGER; }
<INITIAL>int[0-9]*              { if(strlen(dblextext) == 3) {
                                      dblval.intVal = 32;
                                  } else {
                                      dblval.intVal = atol(dblextext + 3);
                                  }
                                  myDebug("INTTYPE %u\n", dblval.intVal);
                                  return INTTYPE; }
<INITIAL>uint[0-9]*             { if(strlen(dblextext) == 4) {
                                      dblval.intVal = 32;
                                  } else {
                                      dblval.intVal = atol(dblextext + 4);
                                  }
                                  myDebug("UINTTYPE %u\n", dblval.intVal);
                                  return UINTTYPE; }
<INITIAL>[a-zA-Z][a-zA-Z0-9_]*  { myDebug("IDENT %s\n", dblextext);
                                  dblval.symVal = utSymCreate(dblextext);
                                  return IDENT; }
<INITIAL>\"([^"]|\\.)*\"      { myDebug("STRING %s\n", dblextext);
                                  dblval.stringVal = utSymCreate(unmunge(dblextext));
                                  return STRING; }
<INITIAL>\[([^\[\]]|\\.)*\]      { myDebug("INDEX %s\n", dblextext);
                                  dblval.indexVal = utSymCreate(unmunge(dblextext));
                                  return INDEX; }
<INITIAL>.                      { myDebug("Char '%c'\n", dblextext[0]);
                                  return dblextext[0]; }
