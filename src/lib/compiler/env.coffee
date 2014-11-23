{extend, str, javascriptKeywordSet, entity, identifierCharSet, assert, constant} = require '../utils'

{SYMBOL} = constant

hasOwnProperty = Object::hasOwnProperty

toIdentifier = (symbol) ->
  result = ''
  for c in symbol
    if identifierCharSet[c] then result += c
    else result += '$'
  if javascriptKeywordSet[symbol] then result += '1'
  result

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

  getFunctionEnv: ->
    env = @
    while not env.functionInfo then env = env.parent
    env

  newVar: (symbol) ->
    name = toIdentifier(symbol)
    functionInfo = @getFunctionInfo()
    if not hasOwnProperty.call(functionInfo, name)
      functionInfo[name] = 1; {value:name, kind:SYMBOL}
    else
      while symbolIndex = name+(++functionInfo[name])
        if not hasOwnProperty.call(functionInfo, symbolIndex) then break
      functionInfo[symbolIndex] = 1
      {value:symbolIndex, kind:SYMBOL, transformed:true}

  constVar: (symbol) -> v = @newVar(symbol); v.const = true; v
  ssaVar: (symbol) -> v = @newVar(symbol); v.ssa = true; v

  #__taiji$AnyIdentifier__ -> __taiji$AnyIdentifier???__, where ??? is index to avoid conflicting
  newTaijiVar: (symbol) ->
    name = toIdentifier(symbol)
    functionInfo = @getFunctionInfo()
    if not hasOwnProperty.call(functionInfo, name)
      functionInfo[name] = 1; {value: name, kind:SYMBOL, transformed:true}
    else
      while symbolIndex = name[...name.length-2]+(++functionInfo[name])+name[name.length-2...]
        if not hasOwnProperty.call(functionInfo, symbolIndex) then break
      functionInfo[symbolIndex] = 1
      {value: symbolIndex, kind:SYMBOL}

  getSymbolIndex: (symbol) ->
    functionInfo = @getFunctionInfo()
    if not hasOwnProperty.call(functionInfo, symbol) then return 0
    else return functionInfo[symbol]

  hasLocal: (symbol) ->  hasOwnProperty.call(@scope, symbol)

  hasFnLocal: (symbol) ->
    if hasOwnProperty.call(@scope, symbol) then return true
    if @functionInfo then return
    else if @parent then return @parent.hasFnLocal(symbol)

  # all variables name relating to symbol
  fnLocalNames: (symbol) ->
    names = {}
    env = @
    while 1
      if env.scope and hasOwnProperty.call(env.scope, symbol)
        names[env.scope[symbol].symbol] = 1
      if env.functionInfo then return names
      else if env.parent then env = env.parent
      else return names

  # use @@x to get variable x in outer var scope( outer function or module variable)
  outerVarScopeEnv: ->
    parent = @
    while 1
      if parent.functionInfo
        if parent.parent then return parent.parent
        else return @ # instead of returning parent, return @. because the check in core.coffee exports['='] if env!=outerEnv and env.get(name)
      else parent = parent.parent

  # todo value should be the form: {value:id, kind: SYMBOL}
  set: (symbol, value) ->
    assert value.value and value.kind==SYMBOL, 'env.set: '+str(value)
    functionInfo = @getFunctionInfo()
    name = toIdentifier(value.value)
    if not functionInfo[name] then functionInfo[name] = 1
    @scope[symbol] = value

  get: (symbol) ->
    env = @
    while env
      scope = env.scope
      if hasOwnProperty.call(scope, symbol) then  return scope[symbol]
      env =  env.parent

  info: (symbol) ->
    if @optimizeInfoMap and hasOwnProperty.call(@optimizeInfoMap, symbol) then  return @optimizeInfoMap[symbol]
    else if @parent then return @parent.info(symbol)

# analysis and optimization use the same environment, but add the property "optimizeInfoMap" to the env instance
# the root env is the initial env which is be used to convert and transform the exp
# when 'function!' is met, the corresponding env is used.