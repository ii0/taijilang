###
  this file is based on coffeescript/src/helper.coffee(https://github.com/jashkenas/coffeescript)
  Thanks to  Jeremy Ashkenas
  Some stuffs is added or modified for taiji langauge.
###
###
Copyright (c) 2009-2014 Jeremy Ashkenas
Copyright (c) 2014-2015 Caoxingming

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
###

# This file contains the common helper functions that we'd like to share among
# the **Lexer**, **Rewriter**, and the **Nodes**. Merge objects, flatten
# arrays, count characters, that sort of thing.
#

# expression mode should start from 0, because memoIndex+mode based on this
OPERATOR_EXPRESSION = 0; COMPACT_CLAUSE_EXPRESSION = 1;  SPACE_CLAUSE_EXPRESSION = 2; INDENT_EXPRESSION = 3; HASH_KEY_EXPRESSION = 4

NULL=0; NUMBER=1;  STRING=2;  IDENTIFIER=3; SYMBOL=4; REGEXP=5;  HEAD_SPACES=6; CONCAT_LINE=7; PUNCTUATION=8; FUNCTION=9
BRACKET=10; PAREN=11; DATA_BRACKET=12; CURVE=13; INDENT_EXPRESSION=14
NEWLINE=15;  SPACES=16; INLINE_COMMENT=17; SPACES_INLINE_COMMENT=18; LINE_COMMENT=19; BLOCK_COMMENT=20; CODE_BLOCK_COMMENT=21; CONCAT_LINE=22
MODULE_HEADER=23; MODULE=24
NON_INTERPOLATE_STRING=25; INTERPOLATE_STRING=26
INDENT=27; UNDENT=28; HALF_DENT=29; EOI=30; C_BLOCK_COMMENT = 31; SPACE_COMMENT = 32; TAIL_COMMENT=33
SPACE = 34; HASH = 35; RIGHT_DELIMITER = 36; KEYWORD = 37; CONJUNCTION = 38
CODE_BLOCK_COMMENT_LEAD_SYMBOL = 39
PREFIX =40; SUFFIX= 41; BINARY = 42
VALUE = 43; LIST = 44; COMMAND = 45

# SYMBOL, VALUE, LIST, COMMAND: the kind of expression

exports.constant = {
  OPERATOR_EXPRESSION, COMPACT_CLAUSE_EXPRESSION, SPACE_CLAUSE_EXPRESSION, INDENT_EXPRESSION, HASH_KEY_EXPRESSION

  NULL, NUMBER, STRING, IDENTIFIER, SYMBOL, REGEXP, HEAD_SPACES, CONCAT_LINE, PUNCTUATION, FUNCTION,
  BRACKET, PAREN, DATA_BRACKET, CURVE, INDENT_EXPRESSION
  NEWLINE, SPACES, INLINE_COMMENT, SPACES_INLINE_COMMENT, LINE_COMMENT, BLOCK_COMMENT, CODE_BLOCK_COMMENT, CONCAT_LINE
  MODULE_HEADER, MODULE
  NON_INTERPOLATE_STRING, INTERPOLATE_STRING
  INDENT, UNDENT, HALF_DENT, EOI, C_BLOCK_COMMENT, SPACE_COMMENT, TAIL_COMMENT
  SPACE, HASH, RIGHT_DELIMITER, KEYWORD, CONJUNCTION
  CODE_BLOCK_COMMENT_LEAD_SYMBOL
  PREFIX, SUFFIX, BINARY
  VALUE, LIST, COMMAND
}

fs = require('fs')
path = require('path')

stackReg = /at\s+(.*)\s+\((.*):(\d*):(\d*)\)/gi
stackReg2 = /at\s+()(.*):(\d*):(\d*)/gi

_trace = (stackIndex, args) ->
  argsStr = ''
  for arg in args
    if argsStr=='' or argsStr[argsStr.length-2...]==': ' or argsStr[argsStr.length-1]==':' then argsStr += arg.toString()
    else argsStr += ', '+ arg.toString()
  stacklist = (new Error()).stack.split('\n').slice(3)
  s = stacklist[stackIndex]
  sp = stackReg.exec(s) || stackReg2.exec(s)
  if sp && sp.length == 5
    method = sp[1]
    file = path.basename(sp[2])
    line = sp[3]
    pos = sp[4]
    fs.appendFileSync("./debug.log", file+': '+method+': '+line+':'+pos+': '+argsStr+'\r\n')
  else
    fs.appendFileSync("./debug.log", 'noname:  noname: xx: yy: '+argsStr+'\r\n')

exports.log = log = (level, args...) -> _trace(level, args); console.log(args...)
exports.trace = trace = (args...) ->  _trace(0, args)
exports.trace0 = trace0 = (args...) -> _trace(0, args)
exports.trace1 = trace1 = (args...) -> _trace(1, args)
exports.trace2 = trace2 = (args...) -> _trace(2, args)
exports.trace3 = trace3 = (args...) -> _trace(3, args)

exports.charset = charset = (string) ->
  result = {}
  for c in string then result[c] = true
  result

exports.digits = digits = '0123456789'
exports.lowers = lowers = 'abcdefghijklmnopqrstuvwxyz'
exports.uppers = uppers = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
exports.letters = letters = lowers+uppers
exports.letterDigits = letterDigits = letters+digits
exports.letterDigitSet = charset letterDigits
exports.firstIdentifierChars = firstIdentifierChars = '$_'+letters
exports.identifierChars = identifierChars = firstIdentifierChars+digits
exports.taijiIdentifierChars = taijiIdentifierChars = '!?'+identifierChars
exports.digitCharSet = digitCharSet = charset(exports.digits)
exports.letterCharSet = letterCharSet = charset(exports.letters)
exports.firstIdentifierCharSet = charset('$_'+letters)
exports.identifierCharSet = identifierCharSet = charset(identifierChars)
exports.taijiIdentifierCharSet = taijiIdentifierCharSet = charset(taijiIdentifierChars)
exports.taijiIdentifierCharSet = taijiIdentifierCharSet = charset(taijiIdentifierChars)
exports.firstSymbolChars = firstSymbolChars = '!#%^&*-+=?<>|~`'
exports.firstSymbolCharset = charset(firstSymbolChars)

# is head a operator for meta expression?
isMetaOperation = isMetaOperation = (head) -> (head[0]=='#' and head[1]!='-') or head=='include!' or head=='import!' or head=='export!'

# set exp.kind attribute, recursively if exp is array
# normalize expression for compilation, used in multiple phases
# todo: this should be compile time function in taijilang bootstrap compilation program, so it can be optimized greatly.
# to make "analyzed", "transformed", "optimized" being true here, we can avoid switch branch in the following phases.
exports.norm = norm = (exp) ->
  # trace('norm: ', str(exp))
  assert exp!=undefined, 'norm(exp) meet undefined'
  if exp.kind then return exp
  if exp instanceof Array then {value:(for e in exp then norm(e)), kind:LIST}
  else if typeof exp == 'string'
    if exp[0]=='"' then {value:exp, kind:VALUE}
    else
      if isMetaOperation(exp) then {value:exp, kind:SYMBOL, meta:true}
      else {value:exp, kind:SYMBOL}
  else if typeof exp =='object' then exp.kind = SYMBOL; exp
  else {value:exp, kind:VALUE}

# todo: because this the core feature of taiji language, a safer method should be used to avoid redefinition by mistake
exports.QUOTE = {value:'~', kind:SYMBOL}
exports.QUASIQUOTE = {value:'`', kind:SYMBOL}
exports.UNQUOTE = {value:'^', kind:SYMBOL}
exports.UNQUOTE_SPLICE = {value:'^&', kind:SYMBOL}

exports.__TJ__QUOTE = {value:'__tj~', kind:SYMBOL}
exports.__TJ__QUASIQUOTE = {value:'__tj`', kind:SYMBOL}
exports.__TJ__UNQUOTE = {value:'__tj^', kind:SYMBOL}
exports.__TJ__UNQUOTE_SPLICE = {value:'__tj^&', kind:SYMBOL}

exports.str = str = (item) ->
  if isArray(item) then '['+(str(x) for x in item).join(' ')+']'
  else if typeof item =='object'
    if item.symbol? then item.symbol
    else str(item.value)
  else if item==undefined then 'undefined'
  else if item==null then 'null'
  else item.toString()

exports.stringifyQuote = stringifyQuote = (item) ->
  kind = item.kind
  switch kind
    when SYMBOL, VALUE
      result = {value:item.value, kind:kind}
    when LIST
      value = for e in item.value then stringifyQuote(e)
      result = {value:value, kind:kind}
    else trace2 'wrong kind: '+kind+': '+str(item)
  if item.type then result.type = item.type
  if item.cursor then result.cursor = item.cursor
  if item.stopCursor then result.stopCursor = item.stopCursor
  if item.line then result.line = item.line
  if item.column then result.column = item.column
  if (start=item.start) and start!=item
    start = extend {}, start
    delete start['value']
    result.start = start
  if (stop=item.stop) and stop!=item
    stop = extend {}, stop
    delete stop['value']
    result.stop = stop
  JSON.stringify(result)

exports.assert = assert = (value, message) ->
    if not value
      trace2('assert:', message or 'assert failed')
      throw new Error message or 'assert failed'

exports.isArray = isArray = (exp) -> Object::toString.call(exp) == '[object Array]'

exports.extend = extend = (object, args...) ->
  if !object then return object;
  for arg in args then(for key, value of arg then object[key] = value)
  object

exports.error = error = (message, symbol) ->
  if symbol then throw message+': '+symbol else throw message

exports.hasOwnProperty = Object.hasOwnProperty

exports.debugging = false
exports.testing = false
exports.debug = (message) -> if exports.debugging then console.log message
exports.warn = (message) -> if exports.debugging or exports.testing then console.log message

exports.convertIdentifier = (name) ->
  result = ''
  for c in entity(name)
    if c=='!' or c=='?' or c=='#' then result += '$' else result += c
  result

exports.splitSpace = (text) ->
  result = []; i = 0; word = ''
  while 1
    c = text[i++]
    if c==' ' or c=='\t' or c=='\n' or c=='\r' then if word then result.push word; word = ''
    else if not c then (if word then result.push word; word = ''); if not c then break
    else word += c
  result

exports.extend = (object, args...) ->
  if !object then return object;
  for arg in args then(for key, value of arg then object[key] = value)
  object

exports.isArray = isArray = (exp) -> Object::toString.call(exp) == '[object Array]'

exports.mergeSet = (sets...) ->
  result = {}
  for x in sets
    for k in x
      if hasOwnProperty.call(x, k) then result[k] = true
  result

exports.entity = entity = (exp) ->
  if exp instanceof Array
    if exp.length==0 then return exp
    else return (for e in exp then entity e)
  if typeof exp == 'object'
    return entity(exp.value)
  exp

exports.kindSymbol = (e) -> {value:e, kind:SYMBOL}

# return value:
# undefined: meet return, throw, break, continue
# value, symbol: meet value or symbol
# LIST: meet list, this depends constant LIST != 0
addBeginItem = (result, exp) ->
  switch exp.kind
    when VALUE, SYMBOL then return exp
    when LIST
      expValue = exp.value
      exp0Value = expValue[0].value
      if exp0Value=='begin!'
        for e in expValue[1...]
          last = addBeginItem(result, e)
          if not last then return
        return last
      else if exp0Value=='return' or exp0Value=='throw' or exp0Value=='break' or exp0Value=='continue'
        result.push(exp); return
      else result.push exp; return LIST
    else
      trace('addBeginItem: wrong kind: '+str(exp))
      throw 'addBeginItem: wrong kind: '+str(exp)

exports.begin = begin = (exp) ->
    result = []
    for e in exp
      last = addBeginItem(result, e)
      if not last then break
    if last and last!=LIST then result.push last
    if result.length>1 then result.unshift norm('begin!'); return norm(result)
    else if result.length==1 then return result[0]
    else return undefinedExp

returnFnMap =
  'break': (exp) -> exp
  'continue': (exp) -> exp
  'throw': (exp) -> exp
  'begin!': (exp) -> exp[exp.length-1] = return_(exp[exp.length-1] ); exp
  'if': (exp) ->
    exp[2] =  return_(exp[2])
    if exp[3] then exp[3] =  return_(exp[3])
    exp
  'switch': (exp) ->
    for case_ in exp[2] then case_[1] = return_(case_)
    exp[3] = return_(exp[3])
    exp
  # c-for, for-in, for-of, while, doWhile: use transformExpression
  'try': (exp) ->
    exp[1] =  return_(exp[1]) #test
    # exp[2]: catch var
    exp[3] = return_(exp[3]) #catch body
    exp[4] = return_(exp[4]) #finally body
    exp
  'letloop': (exp) -> exp[3] = return_(exp[3]); exp

exports.return_ = return_ = (exp) ->
  if not exp then return exp
  if not exp.push then return [norm('return'), exp]
  if fn=returnFnMap[exp[0]] then return fn(exp)
  [norm('return'), exp]

exports.pushExp = (lst, v) -> norm ['call!', ['attribute!', lst, 'push'], [v]]
exports.notExp = (exp) -> norm ['prefix!', '!', exp]
exports.undefinedExp = undefinedExp = norm 'undefined'
exports.commentPlaceholder = {} # used as the second part of transformExpression of comment

exports.isUndefinedExp = -> (exp) -> exp==undefinedExp

# get the truth value of exp under env
# 0: truth value is unknown
# 1: truth value is true
# 2: truth value is false
# todo: use kind(VALUE, SYMBOL, LIST) to optimize the code below
truth = (exp, env) ->
  exp = entity(exp)
  if not exp? then return 2-!!exp
  if typeof exp == 'string'
    if exp[0]=='"' then return 2-!!exp[1...exp.length-1]
    else return
  else if exp.push then return
  return 2-!!exp

exports.addPrelude = (parser, body) ->
  # return body
  result = []
  #if parser.meetEllipsis then result.push ['=', '__slice', ['attribute!', [], 'slice']]
  #result.push ['var', '__slice']
  #result.push ['#/=', '__slice', ['attribute!', [], 'slice']]
  #result.push ['var', '__hasProp']
  #result.push ['#/=', '__hasProp', ['attribute!', ['hash!'], 'hasOwnProperty']]

  #result.push ['include!', '"prelude.tj"']
  #result.push ['directLineComment!', '/// end of prelude']
  #result.push body
  #begin(result)
  body

exports.realCode = (code) ->
  endModuleText = '/// end of prelude;\n'
  if ((realCodePos=code.indexOf(endModuleText))>=0)
    if code[code.length-1]==';'then code.slice(realCodePos+endModuleText.length, code.length-1)
    else code.slice(realCodePos+endModuleText.length)
  else code

exports.dict = (pairs...) ->
  d = {}; i = 0; pairsLength = pairs.length
  while i<pairsLength
    d[pairs[i]] = pairs[i+1]
    i += 2
  d

exports.list2dict = (keys...) ->
  d = {}
  for k in keys then d[k] = 1
  d

exports.extendSyntaxInfo = (result, start, stop) ->
  result.start = start
  if stop then result.stop = stop
  result

# pretty print internal result
exports.formatTaijiJson = formatTaijiJson = (exp, level, start, newline, indent, lineLength) ->
  if newline then head = repeat(repeat(' ', indent), level)
  else head = ''
  body = JSON.stringify(exp)
  if start+(x=(head+body)).length<lineLength then return x
  result = head
  if Object.prototype.toString.call(exp) == '[object Array]'
    exp0 = exp[0]
    result += '['+ formatTaijiJson(exp0, level, 0, false, indent, lineLength)
    if exp0=='begin!' or exp0=='do'
      for x, i in exp.slice(1)
        result += ',\n'+formatTaijiJson(x, level+1, 0, true, indent, lineLength)
    else if exp0=='if'
      result += ', '+formatTaijiJson(exp[1], level, result.length, false, indent, lineLength)
      result += ',\n'+formatTaijiJson(exp[2], level+1, 0, true, indent, lineLength)
      if exp[3] then result += ',\n'+formatTaijiJson(exp[3], level+1, 0, true, indent, lineLength)
    else if exp0
      if exp0[exp0.length-1]=='='
        result += ', '+formatTaijiJson(exp[1], level+1, result.length, false, indent, lineLength)
        result += ',\n'+formatTaijiJson(exp[2], level+1, 0, true, indent, lineLength)
      else if exp0.slice and ((x=exp0[exp0.length-2...])=='->' or x=='=>')
        result += ', '+formatTaijiJson(exp[1], level, result.length, false, indent, lineLength)
        result += ',\n'+formatTaijiJson(exp[2], level+1, 0, true, indent, lineLength)
      else
        for x in exp[1...]
          if result.length>40
            result += '\n'+formatTaijiJson(x, level+1, 0, true, indent, lineLength)
          else result += ','+formatTaijiJson(x, level, result.length, false, indent, lineLength)
    else
      for x in exp[1...]
        if result.length>40
          result += '\n'+formatTaijiJson(x, level+1, 0, true, indent, lineLength)
        else result += ','+formatTaijiJson(x, level, result.length, false, indent, lineLength)
    return result+']'
  else JSON.stringify(exp)

# transform.coffee: merge list of variable list
exports.mergeList = (lists...) ->
  list0 = lists[0]
  for l in lists then list0.push.apply list0, l
  list0

# the above is coded by Caoxingming

# the below is from github.com/jashkenas/coffeescript and modified by Caoxingming

# Merge objects, returning a fresh copy with attributes from both sides.
# Used every time `Base#compile` is called, to allow properties in the
# options hash to propagate down the tree without polluting other branches.
exports.merge = (options, overrides) ->
  extend (extend {}, options), overrides

# Return a flattened version of an array.
# Handy for getting a list of `children` from the nodes.
exports.flatten = flatten = (array) ->
  flattened = []
  for element in array
    if element instanceof Array
      flattened = flattened.concat flatten element
    else
      flattened.push element
  flattened

# Typical Array::some
exports.some = Array::some ? (fn) ->
  return true for e in this when fn e
  false

# Merge two jison-style location data objects together.
# If `last` is not provided, this will simply return `first`.
buildLocationData = (first, last) ->
  if not last
    first
  else
    first_line: first.first_line
    first_column: first.first_column
    last_line: last.last_line
    last_column: last.last_column

# Convert jison location data to a string.
# `obj` can be a token, or a locationData.
exports.locationDataToString = (obj) ->
  if ("2" of obj) and ("first_line" of obj[2]) then locationData = obj[2]
  else if "first_line" of obj then locationData = obj

  if locationData "{locationData.first_line + 1}:{locationData.first_column + 1}-{locationData.last_line + 1}:{locationData.last_column + 1}"
  else "No location data"

# A `.taiji.md` compatible version of `basename`, that returns the file sans-extension.
exports.baseFileName = (file, stripExt = no, useWinPathSep = no) ->
  pathSep = if useWinPathSep then /\\|\// else /\//
  parts = file.split(pathSep)
  file = parts[parts.length - 1]
  return file unless stripExt and file.indexOf('.') >= 0
  parts = file.split('.')
  parts.pop()
  parts.pop() if (parts[parts.length - 1] is 'taiji' or parts[parts.length - 1] is 'tj') and parts.length > 1
  parts.join('.')

# Determine if a filename represents a taiji file.
exports.isTaiji = (file) -> /\.(taiji|tj|taiji.json|tj.json)$/.test file

# Throws a SyntaxError from a given location.
# The error's `toString` will return an error message following the "standard"
# format <filename>:<line>:<col>: <message> plus the line with the error and a marker showing where the error is.
exports.throwSyntaxError = (message, location) ->
  error = new SyntaxError message
  error.location = location
  error.toString = syntaxErrorToString
  # Instead of showing the compiler's stacktrace, show our custom error message
  # (this is useful when the error bubbles up in Node.js applications that compile taiji for example).
  error.stack = error.toString()
  throw error

# Update a compiler SyntaxError with source code information if it didn't have it already.
exports.updateSyntaxError = (error, code, filename) ->
  # Avoid screwing up the `stack` property of other errors (i.e. possible bugs).
  if error.toString is syntaxErrorToString
    error.code or= code
    error.filename or= filename
    error.stack = error.toString()
  error

syntaxErrorToString = ->
  return Error::toString.call @ unless @code and @location

  {first_line, first_column, last_line, last_column} = @location
  last_line ?= first_line
  last_column ?= first_column

  filename = @filename or '[stdin]'
  codeLine = @code.split('\n')[first_line]
  start    = first_column
  # Show only the first line on multi-line errors.
  end      = if first_line is last_line then last_column + 1 else codeLine.length
  marker   = repeat(' ', start) + repeat('^', end - start)

  # Check to see if we're running on a color-enabled TTY.
  if process? then colorsEnabled = process.stdout.isTTY and not process.env.NODE_DISABLE_COLORS

  if @colorful ? colorsEnabled
    colorize = (str) -> "\x1B[1;31m#{str}\x1B[0m"
    codeLine = codeLine[...start] + colorize(codeLine[start...end]) + codeLine[end..]
    marker   = colorize marker

  """
    #{filename}:#{first_line + 1}:#{first_column + 1}: error: #{@message}
    #{codeLine}
    #{marker}
  """

# Repeat a string `n` times.
exports.repeat = repeat = (str, n) ->
  # Use clever algorithm to have O(log(n)) string concatenation operations.
  res = ''
  while n > 0
    res += str if n & 1
    n >>>= 1
    str += str
  res

javascriptKeywordText = ("break export return case for switch comment function this continue if typeof default import" +
" var delete in void do label while else new with catch enum throw class super extends try const finally debugger")
exports.javascriptKeywordSet = javascriptKeywordSet = {}
do ->
  for w in javascriptKeywordText.split(' ')
    javascriptKeywordSet[w] = 1

