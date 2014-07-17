{extend, javascriptKeywordSet} = require '../utils'
{identifierCharSet} = require '../parser/base'

hasOwnProperty = Object::hasOwnProperty

convertToIdentifier = (symbol) ->
  result = ''
  for c in symbol
    if identifierCharSet[c] then result += c
    else if c=='!' then result += '$'
    else if c=='?' then result += '_$'
    else result += '_'
  if javascriptKeywordSet[symbol] then result += '1'
  result

error = (msg, exp) ->
  if exp then throw Error msg+': '+exp
  else throw Error msg

class SymbolLookupError extends Error
  constructor: (@msg, @exp) ->

# options: {module, functionInfo, parser, ...}
exports.Environment = class Environment
  constructor: (@scope, @parent, @parser, @module, @functionInfo, @options) ->
    if functionInfo
      functionInfo['backFillBlock!'] = []
      @localScopeLevel = 0
    else @localScopeLevel = parent.localScopeLevel+1
    if parent then @meta = parent.meta
    else @meta = {list: [], code: [], index:0, env: @extend({})}

  extend: (scope, parser, module, functionInfo, options) ->
    new Environment(scope or @scope, @, parser or @parser, module or @module, functionInfo, options or @options)

  getFunctionInfo: ->
    env = @
    while not functionInfo = env.functionInfo then env = env.parent
    functionInfo

  newVar: (symbol) ->
    name = convertToIdentifier(symbol)
    functionInfo = @getFunctionInfo()
    if not hasOwnProperty.call(functionInfo, name)
      functionInfo[name] = 1; {symbol: name}
    else
      while symbolIndex = name+(++functionInfo[name])
        if not hasOwnProperty.call(functionInfo, symbolIndex) then break
      functionInfo[symbolIndex] = 1
      {symbol: symbolIndex}
  constVar: (symbol) -> v = @newVar(symbol); v.const = true; v
  ssaVar: (symbol) -> v = @newVar(symbol); v.ssa = true; v

  hasLocal: (symbol) ->  hasOwnProperty.call(@scope, symbol)

  hasFnLocal: (symbol) ->
    if hasOwnProperty.call(@scope, symbol) then return true
    if @functionInfo then return
    else if @parent then return @parent.hasFnLocal(symbol)

  # use @@x to get variable x in outer var scope( outer function or module variable)
  outerVarScopeEnv: ->
    parent = @
    while 1
      if parent.functionInfo
        if parent.parent then return parent.parent
        else return @ # instead of returning parent, return @. because the check in core.coffee exports['='] if env!=outerEnv and env.get(name)
      else parent = parent.parent

  set: (symbol, value) ->
    functionInfo = @getFunctionInfo()
    if not functionInfo[symbol] then functionInfo[symbol] = 1
    @scope[symbol] = value

  get: (symbol) ->
    if hasOwnProperty.call(@scope, symbol) then  return @scope[symbol]
    else if @parent then return @parent.get(symbol)


