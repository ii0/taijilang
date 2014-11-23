{expect, ndescribe, idescribe, iit, nit, matchRule} = require '../util'

lib = '../../lib/'
{constant, isArray, str} = require lib+'utils'
{Parser} = require lib+'parser'

ndescribe "parse: ",  ->
  describe "clause: ",  ->
    parse = (text) ->
      parser = new Parser()
      x = parser.parse(text, matchRule(parser, parser.clause), 0)
      str x

    describe "normal clause: ",  ->
      it 'should parse 3+.#(1+1)', ->
        expect(parse('3+.#(1+1)')).to.equal "[binary! + 3 [prefix! # [() [binary! + 1 1]]]]"
      it 'should parse 1', ->
        expect(parse('1 ')).to.equal "1"
      it 'should parse y+.!1', ->
        expect(parse('y+.!1')).to.equal "[binary! + y [prefix! ! 1]]"
      it 'should parse a.!=1', ->
        expect(parse('a.!=1')).to.equal "[binary! != a 1]"
      it 'should parse a!=1', ->
        expect(parse('a!=1')).to.equal "[binary! != a 1]"
      it 'should parse 1,2', ->
        expect(parse('1,2')).to.equal '1'
      it 'should parse 1 , 2', ->
        expect(parse('1 , 2')).to.equal "1"
      it 'should parse 1 2', ->
        expect(parse('1 2 ')).to.equal '[1 2]'
      it 'should parse print : 1 , 2', ->
        expect(parse('print : 1 , 2')).to.equal "[print 1 2]"
      it 'should parse print : and 1 2', ->
        x = parse('print : and 1 2')
        expect(x).to.equal "[print [and 1 2]]"
      it 'should parse print: and 1 2 , 3', ->
        x = parse('print: and 1 2 , 3')
        expect(x).to.equal "[print [and 1 2] 3]"
      it 'should parse print : add 1 2 , add 3 4', ->
        expect(parse('print : add 1 2 , add 3 4')).to.equal "[print [add 1 2] [add 3 4]]"
      it 'should parse select fn : 1 2 4', ->
        # this is correct parsing result, similar to select fn: pring 2 4
        expect(parse('select fn : 1 2 4')).to.equal "[[select fn] [1 2 4]]"
      it 'should parse select fn : 1, 2, 4', ->
        # this is correct parsing result, similar to select fn: pring 2 4
        expect(parse('select fn : 1, 2, 4')).to.equal "[[select fn] 1 2 4]"
      it 'should parse {select fn} 1 2 4', ->
        # this is correct parsing result, similar to select fn: pring 2 4
        expect(parse('{select fn} 1 2 4')).to.equal "[[{} [select fn]] 1 2 4]"
      it 'should parse {select fn} 1, 2, 4', ->
        # this is correct parsing result, similar to select fn: pring 2 4
        expect(parse('{select fn} 1, 2, 4')).to.equal "[[{} [select fn]] 1]"
      it 'should parse print: add: add 1 2 , add 3 4', ->
        expect(parse('print: add: add 1 2 , add 3 4')).to.equal "[print [add [add 1 2] [add 3 4]]]"
      it 'should parse [2]', ->
        expect(parse("[2]")).to.equal "[[] [2]]"
      it 'should parse [[2]]', ->
        expect(parse("[[2]]")).to.equal "[[] [[[] [2]]]]"
      it 'should parse [[[2] 3]]', ->
        expect(parse("[ [[2] 3] ]")).to.equal "[[] [[[] [[[[] [2]] 3]]]]]"
      it 'should parse require.extensions[".tj"] = 1', ->
        expect(parse('require.extensions[".tj"] = 1')).to.equal "[= [binary! concat[] [binary! . require extensions] [[] [[string! \".tj\"]]]] 1]"
      it 'should parse a = ->', ->
        expect(parse('a = ->')).to.equal "[= a [-> [] undefined]]"
      it 'should parse require.extensions[".tj"] = ->', ->
        expect(parse('require.extensions[".tj"] = ->')).to.equal "[= [binary! concat[] [binary! . require extensions] [[] [[string! \".tj\"]]]] [-> [] undefined]]"
      it 'should parse require.extensions[".tj"] = (module, filename) ->', ->
        expect(parse('require.extensions[".tj"] = (module, filename)  ->')).to.equal "[= [binary! concat[] [binary! . require extensions] [[] [[string! \".tj\"]]]] [-> [() [binary! , module filename]] undefined]]"
      it 'should parse x = ->', ->
        expect(parse('x = ->')).to.equal "[= x [-> [] undefined]]"
      it 'should parse \\"x..." a', ->
        expect(parse('\\"x..." a')).to.equal 'undefined'
      it '''should parse \\'x...' a''', ->
        expect(parse("\\'x...' a")).to.equal '["x..." a]'

    describe "concatenated line clauses: ",  ->
      it 'should parse print 1 \\\n 2 3', ->
        expect(parse('print 1 \\\n 2 3')).to.equal "[print 1 2 3]"
      it 'should parse print 1 \n 2 3', ->
        expect(parse('print 1 \n 2 3')).to.equal "[print 1 [2 3]]"
      it 'should parse print 1 \\\n {print 2 \\\n 3 4} 5', ->
        expect(parse('print 1 \\\n {print 2 \\\n 3 4} 5')).to.equal "[print 1 [{} [print 2 3 4]] 5]"

    describe "clauses which contain in curve or bracket: ",  ->
      it 'should parse [1]', ->
        expect(parse('[1] ')).to.equal "[[] [1]]"
      it 'should parse {1}', ->
        expect(parse('{1} ')).to.equal "[{} 1]"
      it 'should parse {1, 2}', ->
        expect(parse('{1, 2} ')).to.equal "[{} [begin! 1 2]]"
      it 'should parse [1, 2]', ->
        expect(parse('[1, 2] ')).to.equal "[[] [1 2]]"
      it 'should parse {print 1}', ->
        expect(parse('{print 1} ')).to.equal "[{} [print 1]]"
      it 'should parse print {abs 1}', ->
        expect(parse('print {abs 1} ')).to.equal "[print [{} [abs 1]]]"
      it 'should parse print {abs \n 1}', ->
        expect(parse('print {abs \n 1} ')).to.equal "[print [{} [abs 1]]]"

    describe "function:",  ->
      it 'should parse ->', ->
        x = parse('->')
        expect(x).to.equal '[-> [] undefined]'
      it 'should parse -> 1', ->
        x = parse('-> 1')
        expect(x).to.equal "[-> [] 1]"
      it 'should parse () -> 1', ->
        x = parse('() -> 1')
        expect(x).to.equal "[-> [()] 1]"
      it 'should parse (a) -> 1', ->
        x = parse('(a) -> 1')
        expect(x).to.equal "[-> [() a] 1]"
      it 'should parse (a, b) -> 1', ->
        x = parse('(a , b) -> 1')
        expect(x).to.equal "[-> [() [binary! , a b]] 1]"
      it 'should parse (a , b , c) -> 1', ->
        x = parse('(a , b , c) -> 1')
        expect(x).to.equal "[-> [() [binary! , [binary! , a b] c]] 1]"
      it 'should parse (a , b , c) -> -> 1', ->
        x = parse('(a , b , c) -> -> 1')
        expect(x).to.equal "[-> [() [binary! , [binary! , a b] c]] [-> [] 1]]"
      it 'should parse (a , b , 1) -> 1', ->
        expect(parse('(a , b , 1) -> 1')).to.equal "[-> [() [binary! , [binary! , a b] 1]] 1]"
      it 'should parse (a , b + 1) -> 1', ->
        expect(parse('(a , b + 1) -> 1')).to.equal "[-> [() [binary! , a [binary! + b 1]]] 1]"
      it 'should parse -> and 1 2 ; and 3 4', ->
        x = parse('-> and 1 2 ; and 3 4')
        expect(x).to.equal "[-> [] [begin! [and 1 2] [and 3 4]]]"
      it 'should parse -> and 1 2 , and 3 4', ->
        x = parse('-> and 1 2 , and 3 4')
        expect(x).to.equal "[-> [] [begin! [and 1 2] [and 3 4]]]"
      it 'should parse print -> 2', ->
        x = parse('print -> 2')
        expect(x).to.equal "[print [-> [] 2]]"
      it 'should parse -> 1 -> 2', ->
        expect(parse('-> 1 -> 2')).to.equal "[-> [] [1 [-> [] 2]]]"
      it 'should parse -> and 1 2 , and 3 4 -> print x ; print 5 6', ->
        x = parse('-> and 1 2 , and 3 4 -> print x ; print 5 6')
        expect(x).to.equal "[-> [] [begin! [and 1 2] [and 3 4 [-> [] [begin! [print x] [print 5 6]]]]]]"

    describe 'meta: ', ->
      it 'should parse # if 1 then 1+2 else 3+4', ->
        expect(parse('# if 1 then 1+2 else 3+4')).to.equal "[# [if 1 [binary! + 1 2] [binary! + 3 4]]]"

      it 'should compile ## if 1 then 1+2 else 3+4', ->
        expect(parse('## if 1 then 1+2 else 3+4')).to.equal "[## [if 1 [binary! + 1 2] [binary! + 3 4]]]"

      it 'should parse # #(1+2)', ->
        expect(parse('# #(1+2)')).to.equal "[# [prefix! # [() [binary! + 1 2]]]]"

      it 'should parse # #(1+2) + #(3+4)', ->
        expect(parse('# #(1+2) + #(3+4)')).to.equal "[# [binary! + [prefix! # [() [binary! + 1 2]]] [prefix! # [() [binary! + 3 4]]]]]"

      it 'should parse # (#(1+2) + #(3+4))', ->
        expect(parse('# (#(1+2) + #(3+4))')).to.equal "[# [() [binary! + [prefix! # [() [binary! + 1 2]]] [prefix! # [() [binary! + 3 4]]]]]]"

      it 'should parse # ( #(1+2) + #(3+4))', ->
        expect(parse('# ( #(1+2) + #(3+4))')).to.equal "[# [() [binary! + [prefix! # [() [binary! + 1 2]]] [prefix! # [() [binary! + 3 4]]]]]]"

    describe 'class: ', ->
      it 'should parse class A', ->
        x = parse('class A')
        expect(x).to.equal "[#call! class [A undefined undefined]]"

      it 'should parse class A :: = ->', ->
        x = parse('class A :: = ->')
        expect(x).to.equal "[#call! class [A undefined [= :: [-> [] undefined]]]]"

      it 'should parse class B extends A :: = ->', ->
        x = parse('class B extends A :: = ->')
        expect(x).to.equal "[#call! class [B A [= :: [-> [] undefined]]]]"

      it 'should parse class B extends A', ->
        x = parse('class B extends A')
        expect(x).to.equal "[#call! class [B A undefined]]"

      it 'should parse class B extends A  :: = ->', ->
        x = parse('class B extends A  :: = ->')
        expect(x).to.equal "[#call! class [B A [= :: [-> [] undefined]]]]"

    describe 'for', ->
      it 'should parse for (i=0; i<10; i++) then print i', ->
        x = parse('for (i=0; i<10; i++) then print i')
        expect(x).to.equal "[cFor! [binary! = i 0] [binary! < i 10] [suffix! ++ i] [print i]]"

      it 'should parse for i in x then print i', ->
        x = parse('for i in x then print i')
        expect(x).to.equal "[forIn! i undefined x [print i]]"

      it 'should parse for i v in x then print i, print v', ->
        x = parse('for i v in x then print i, print v')
        expect(x).to.equal "[forIn! i v x [begin! [print i] [print v]]]"

      it 'should parse for i, v of x then print i, print v', ->
        x = parse('for i, v of x then print i, print v')
        expect(x).to.equal "[forOf! i v x [begin! [print i] [print v]]]"

      it 'should parse label: forx# for i, v in x then print i', ->
        x = parse('forx#: for i, v in x then print i, print v')
        expect(x).to.equal "[label! forx [forIn! i v x [begin! [print i] [print v]]]]"

    describe 'var', ->
      it 'should parse var a', ->
        x = parse('var a')
        expect(x).to.equal "[var a]"

      it 'should parse var a = 1', ->
        x = parse('var a = 1')
        expect(x).to.equal "[var [= a 1]]"

      it 'should parse var a = \n 1', ->
        x = parse('var a = \n 1')
        expect(x).to.equal "[var [= a 1]]"

      it 'should parse var \n a =  1', ->
        x = parse('var \n a = 1')
        expect(x).to.equal "[var [= a 1]]"

      it 'should parse var \n a = \n  1\n b', ->
        x = parse('var \n a = \n  1\n b')
        expect(x).to.equal "[var [= a 1] b]"

      it 'should parse var a,b', ->
        x = parse('var a,b')
        expect(x).to.equal "[var a b]"

      it 'should parse var a, 1', ->
        expect( -> parse('var a, 1')).to.throw /unexpected token after var initialization/

      it 'should parse var 1', ->
        expect( -> parse('var 1')).to.throw /expect variable name/

    describe 'extern!', ->
      it 'should parse extern! x a b', ->
        x = parse('extern! x a b')
        expect(x).to.equal '[extern! x a b]'

    describe 'assign', ->
      it 'should parse a = 1', ->
        x = parse('a = 1')
        expect(x).to.equal '[= a 1]'

      it 'should parse \\if = 1', ->
        x = parse('\\if = 1')
        expect(x).to.equal '[= if 1]'

      it 'should parse a = b = 1', ->
        x = parse('a = b = 1')
        expect(x).to.equal '[= a [= b 1]]'

      it 'should parse a = \n b = 1', ->
        x = parse('a = \n b = 1')
        expect(x).to.equal "[= a [[= b 1]]]"

      it 'should parse a = \n b = \n  1', ->
        x = parse('a = \n b = \n  1')
        expect(x).to.equal "[= a [[= b [1]]]]"

      it 'should parse :: = 1', ->
        x = parse(':: = 1')
        expect(x).to.equal "[= :: 1]"

      it 'should parse {a b c} = x', ->
        x = parse('{a b c} = x')
        expect(x).to.equal "[= [{} [a b c]] x]"

      it 'should parse {a b c\\\ne f} = x', ->
        x = parse('{a b c\\\n e f} = x')
        expect(x).to.equal "[= [{} [a b c e f]] x]"

      it 'should parse {a} = x', ->
        x = parse('{a} = x')
        expect(x).to.equal "[= [{} a] x]"

    describe 'unquote!', ->
      it 'should parse ^ a', ->
        x = parse('^ a')
        expect(x).to.equal "[^ a]"

      it 'should parse ^& a', ->
        x = parse('^& a')
        expect(x).to.equal "[^& a]"

      it 'should parse ^&a', ->
        x = parse('^&a')
        expect(x).to.equal "[prefix! ^& a]"

    describe 'expression clause:', ->
      it 'should parse 1+2', ->
        x = parse('1+2')
        expect(x).to.equal "[binary! + 1 2]"

      it 'should parse print 1+2', ->
        x = parse('print 1+2')
        expect(x).to.equal "[print [binary! + 1 2]]"

      it 'should parse print (1+2)', ->
        x = parse('print (1+2)')
        expect(x).to.equal "[print [() [binary! + 1 2]]]"

      it 'should parse print (1 + 2)', ->
        x = parse('print (1 + 2)')
        expect(x).to.equal "[print [() [binary! + 1 2]]]"

      it 'should parse print 1 + 2', ->
        x = parse('print 1 + 2')
        expect(x).to.equal "[print [binary! + 1 2]]"

      it 'should parse 1 + 2', ->
        x = parse('1 + 2')
        expect(x).to.equal "[binary! + 1 2]"

    describe "do statement: ",  ->
      it 'should parse do print 1; print 2; where a = 1', ->
        x = parse('do print 1; print 2; where a = 1')
        expect(x).to.equal "[let [[= a 1]] [begin! [print 1] [print 2]]]"
      it 'should parse do print 1; print 2; where a = 1, b = 2', ->
        x = parse('do print 1; print 2; where a = 1, b = 2')
        expect(x).to.equal "[let [[= a 1] [= b 2]] [begin! [print 1] [print 2]]]"
      it 'should parse do print 1; print 2; when a==1', ->
        x = parse('do print 1; print 2; when a==1')
        expect(x).to.equal "[doWhile! [begin! [print 1] [print 2]] [binary! == a 1]]"
      it 'should parse do print 1; print 2; while a==1', ->
        expect(-> parse('do print 1; print 2; while a==1')).to.throw /unexpected end of input/
      it 'should parse do print 1; print 2; until a==1', ->
        x = parse('do print 1; print 2; until a==1')
        expect(x).to.equal "[doWhile! [begin! [print 1] [print 2]] [prefix ! [binary! == a 1]]]"

  describe "sentence: ",  ->
    parse = (text) ->
      parser = new Parser()
      x = parser.parse(text, matchRule(parser, parser.sentence), 0)
      str x
    describe "old test: ",  ->
      it 'should parse print 1 , print 2', ->
        x = parse('print 1 , print 2')
        expect(x).to.equal "[[print 1] [print 2]]"
      it 'should parse if and 1 2 then 3', ->
        x = parse('if and 1 2 then 3')
        expect(x).to.equal "[[if [and 1 2] 3]]"
      it 'should parse if and 1 2 then\n 3', ->
        x = parse('if and 1 2 then\n 3')
        expect(x).to.equal "[[if [and 1 2] 3]]"
      it 'should parse if add : add 1 2 , add 3 4 then 5', ->
        x = parse('if add : add 1 2 , add 3 4 then 5')
        expect(x).to.equal "[[if [add [add 1 2] [add 3 4]] 5]]"
      it 'should parse print : and 1 2 , or : eq 3 4 , eq 5 6', ->
        x = parse('print : and 1 2 , or : eq 3 4 , eq 5 6')
        expect(x).to.equal "[[print [and 1 2] [or [eq 3 4] [eq 5 6]]]]"

    describe "old test 2: ",  ->
      it 'should parse if 2 then 3 else 4', ->
        x = parse('if 2 then 3 else 4')
        expect(x).to.equal "[[if 2 3 4]]"
      it 'should parse print 1 , if 2 then 3 else 4', ->
        x = parse('print 1 , if 2 then 3 else 4')
        expect(x).to.equal "[[print 1] [if 2 3 4]]"
      it 'should parse if 1 then 2 else if 1 then 2 else 3', ->
        x = parse('if 1 then 2 else if 1 then 2 else 3')
        expect(x).to.equal "[[if 1 2 [if 1 2 3]]]"
      it 'should parse if 1 then if 2 then 3 else 4 else 5', ->
        x = parse('if 1 then if 2 then 3 else 4 else 5')
        expect(x).to.equal "[[if 1 [if 2 3 4] 5]]"

    describe "if statement: ",  ->
      describe "group1: ",  ->
        it 'should parse if 1 then 2', ->
          x = parse('if 1 then 2')
          expect(x).to.equal "[[if 1 2]]"
        it 'should parse if 1 else 2', ->
          expect(try -> parse('if 1 else 2')).to.throw  /unexpected conjunction "else"/
        it 'should parse if 1 then 2 else 3', ->
          x = parse('if 1 then 2 else 3')
          expect(x).to.equal "[[if 1 2 3]]"
        it 'should parse if 1 then 2 \nelse 3', ->
          x = parse('if 1 then 2 \nelse 3')
          expect(x).to.equal "[[if 1 2 3]]"
        it 'should parse if 1 then \n  2 \nelse 3', ->
          x = parse('if 1 then \n  2 \nelse 3')
          expect(x).to.equal "[[if 1 2 3]]"
        it 'should parse if 1 \nthen 2 \nelse 3', ->
          x = parse('if 1 \nthen 2 \nelse 3')
          expect(x).to.equal "[[if 1 2 3]]"

      describe "group2: ",  ->
        it 'should parse if 1 then\n  2 \nelse 3', ->
          expect(parse('if 1 then\n  2 \nelse 3')).to.equal "[[if 1 2 3]]"
        it 'should parse if 1 then if 2 then 3', ->
          x = parse('if 1 then if 2 then 3')
          expect(x).to.equal "[[if 1 [if 2 3]]]"
        it 'should parse if 1 then if 2 then 3 else 4', ->
          x = parse('if 1 then if 2 then 3 else 4')
          expect(x).to.equal "[[if 1 [if 2 3 4]]]"
        it 'should parse if 1 then if 2 then 3 \nelse 4', ->
          x = parse('if 1 then if 2 then 3 \nelse 4')
          expect(x).to.equal "[[if 1 [if 2 3] 4]]"
        it 'should parse if 1 then \n if 2 then 3 \nelse 4', ->
          x = parse('if 1 then \n if 2 then 3 \nelse 4')
          expect(x).to.equal "[[if 1 [if 2 3] 4]]"
        it 'should parse if 1 then\n if 2 then 3 \n else 4', ->
          x = parse('if 1 then\n if 2 then 3 \n else 4')
          expect(x).to.equal "[[if 1 [if 2 3 4]]]"

    describe "while statement: ",  ->
      it 'should parse while 1 then 2', ->
        x = parse('while 1 then 2')
        expect(x).to.equal "[[while 1 2]]"
      it 'should parse while 1 else 2', ->
        expect(try -> parse('while 1 else 2')).to.throw /unexpected conjunction "else"/
      it 'should parse while 1 then \n while 2 then 3 \nelse 4', ->
        x = parse('while 1 then \n while 2 then 3 \nelse 4')
        expect(x).to.equal "[[while 1 [while 2 3] 4]]"
      it 'should parse while 1 then\n while 2 then 3 \n else 4', ->
        x = parse('while 1 then\n while 2 then 3 \n else 4')
        expect(x).to.equal "[[while 1 [while 2 3 4]]]"

    describe "try statement: ",  ->
      describe "group1: ",  ->
        it 'should parse try 1 catch e then 2', ->
          x = parse('try 1 catch e then 2')
          expect(x).to.equal "[[try 1 e 2 undefined]]"
        # javascript try-catch has no else clause.
        nit 'should parse try 1 else 2', ->
          x = parse('try 1 else 2')
          expect(x).to.equal "[[try 1 [list!] 2 undefined]]"
        nit 'should parse try 1 catch e then 2 else 3', ->
          x = parse('try 1 catch e then 2 else 3')
          expect(x).to.equal "[[try 1 [list! [e 2]] 3 undefined]]"
        nit 'should parse try 1 catch e then 2 \nelse 3', ->
          x = parse('try 1 catch e then 2 \nelse 3')
          expect(x).to.equal "[[try 1 [list! [e 2]] 3 undefined]]"
        nit 'should parse try 1 catch e then \n  2 \nelse 3', ->
          x = parse('try 1 catch e then \n  2 \nelse 3')
          expect(x).to.equal "[[try 1 [list! [e 2]] 3 undefined]]"
        nit 'should parse try 1 \ncatch e then 2 \nelse 3', ->
          x = parse('try 1 \ncatch e then 2 \nelse 3')
          expect(x).to.equal "[[try 1 [list! [e 2]] 3 undefined]]"
        nit 'should parse try 1 \n  2 \nelse 3', ->
          expect(parse('try 1 \n  2 \nelse 3')).to.equal "[[try [1 2] [list!] 3 undefined]]"
      describe "group2: ",  ->
        it 'should parse try 1 catch e then try 2 catch e then 3', ->
          x = parse('try 1 catch e then try 2 catch e then 3')
          expect(x).to.equal "[[try 1 e [try 2 e 3 undefined] undefined]]"
        nit 'should parse try 1 catch e then try 2 catch e then 3 else 4', ->
          x = parse('try 1 catch e then try 2 catch e then 3 else 4')
          expect(x).to.equal "[[try 1 [list! [e [try 2 [list! [e 3]] 4 undefined]]] undefined undefined]]"
        nit 'should parse try 1 catch e then try 2 catch e then 3 \nelse 4', ->
          x = parse('try 1 catch e then try 2 catch e then 3 \nelse 4')
          expect(x).to.equal "[[try 1 [list! [e [try 2 [list! [e 3]] undefined undefined]]] 4 undefined]]"
        nit 'should parse try 1 catch e then \n try 2 catch e then 3 \nelse 4', ->
          x = parse('try 1 catch e then \n try 2 catch e then 3 \nelse 4')
          expect(x).to.equal "[[try 1 [list! [e [try 2 [list! [e 3]] undefined undefined]]] 4 undefined]]"
        nit 'should parse try 1 catch e then\n try 2 catch e then 3 \n else 4', ->
          x = parse('try 1 catch e then\n try 2 catch e then 3 \n else 4')
          expect(x).to.equal "[[try 1 [list! [e [try 2 [list! [e 3]] 4 undefined]]] undefined undefined]]"
        it 'should parse try \n 1 catch e then\n 2', ->
          expect(-> parse('try \n 1 catch e then\n 2')).to.throw /unexpected conjunction "catch" following a indent block/
        it 'should parse try \n 1 \ncatch e then\n 2', ->
          expect(-> parse('try \n 1 catch e then\n 2')).to.throw /unexpected conjunction "catch" following a indent block/

    describe "try if statement: ",  ->
      it 'should parse try if 1 then 2 catch e then 3', ->
        x = parse('try if 1 then 2 catch e then 3')
        expect(x).to.equal "[[try [if 1 2] e 3 undefined]]"

    describe "switch statement: ",  ->
      describe "group1: ",  ->
        it 'should parse switch 1 case e: 2', ->
          x = parse('switch 1 case e: 2')
          expect(x).to.equal "[[switch 1 [[[e] 2]] undefined]]"
        it 'should parse switch 1 else 2', ->
          x = parse('switch 1 else 2')
          expect(x).to.equal "[[switch 1 [] 2]]"
        it 'should parse switch 1 case e: 2 else 3', ->
          x = parse('switch 1 case e: 2 else 3')
          expect(x).to.equal "[[switch 1 [[[e] 2]] 3]]"
        it 'should parse switch 1 case e: 2 \nelse 3', ->
          # else is not belong to this switch
          expect(parse('switch 1 case e: 2 \nelse 3')).to.equal "[[switch 1 [[[e] 2]] undefined]]"
        it 'should parse switch 1 case e: 2 \n  else 3', ->
          # else is not belong to this switch
          expect(parse('switch 1 case e: 2 \n  else 3')).to.equal "[[switch 1 [[[e] 2]] 3]]"
        it 'should parse switch 1 case e: \n  2 \nelse 3', ->
          x = parse('switch 1 case e: \n  2 \nelse 3')
          expect(x).to.equal "[[switch 1 [[[e] 2]] undefined]]"
        it 'should parse switch 1 \n case e: 2 \n else 3', ->
          x = parse('switch 1 \n case e: 2 \n else 3')
          expect(x).to.equal "[[switch 1 [[[e] 2]] 3]]"
        it 'should parse switch 1 \n case 2: 4 \n else 3', ->
          expect(parse('switch 1 \n case 2: 4 \n else 3')).to.equal "[[switch 1 [[[2] 4]] 3]]"
        it 'should parse switch 1 \n  case 2: 4 \n else 3', ->
          expect(parse('switch 1 \n  case 2: 4 \n else 3')).to.equal "[[switch 1 [[[2] 4]] undefined]]"
        it 'should parse switch 1 case e: switch 2 case e: 3', ->
          x = parse('switch 1 case e: switch 2 case e: 3')
          expect(x).to.equal "[[switch 1 [[[e] [switch 2 [[[e] 3]] undefined]]] undefined]]"

      describe "group2: ",  ->
        it 'should parse switch 1 case e: switch 2 case e: 3 else 4', ->
          x = parse('switch 1 case e: switch 2 case e: 3 else 4')
          expect(x).to.equal "[[switch 1 [[[e] [switch 2 [[[e] 3]] 4]]] undefined]]"
        it 'should parse switch 1 case e: switch 2 case e: 3 \nelse 4', ->
          x = parse('switch 1 case e: switch 2 case e: 3 \nelse 4')
          expect(x).to.equal "[[switch 1 [[[e] [switch 2 [[[e] 3]] undefined]]] undefined]]"
        it 'should parse switch 1 case e: \n switch 2 case e: 3 \nelse 4', ->
          x = parse('switch 1 case e: \n switch 2 case e: 3 \nelse 4')
          expect(x).to.equal "[[switch 1 [[[e] [switch 2 [[[e] 3]] undefined]]] undefined]]"
        it 'should parse switch 1 case e:\n switch 2 case e: 3 \n else 4', ->
          expect(-> parse('switch 1 case e:\n switch 2 case e: 3 \n else 4')).to.throw /unexpected conjunction "else" following a indent block/
        it 'should parse switch 1 case e:\n   switch 2 case e: 3 \n else 4', ->
          expect(parse('switch 1 case e:\n   switch 2 case e: 3 \n else 4')).to.equal "[[switch 1 [[[e] [switch 2 [[[e] 3]] undefined]]] 4]]"

    describe "let statement: ",  ->
      it 'should parse let a = 1 then 2', ->
        x = parse('let a = 1 then 2')
        expect(x).to.equal "[[let [[= a 1]] 2]]"
      it 'should parse let a = 1 \nthen 2', ->
        x = parse('let a = 1 \nthen 2')
        expect(x).to.equal "[[let [[= a 1]] 2]]"
      it 'should parse let a = 1, b = 3 \nthen 2', ->
        x = parse('let a = 1, b = 3 \nthen 2')
        expect(x).to.equal "[[let [[= a 1] [= b 3]] 2]]"
      it 'should parse let a = abs \n    1, \n  b = 3 \nthen 2', ->
        x = parse('let a = abs \n    1, \n  b = 3 \nthen 2')
        expect(x).to.equal "[[let [[= a [abs 1]] [= b 3]] 2]]"
      it 'should parse letrec! f = (x) -> if! x==1 1 f(x-1) then f(3)', ->
        expect(parse('letrec! f = (x) -> if! x==1 1 f(x-1) then f(3)')).to.equal "[[letrec! [[= f [-> [() x] [if! [binary! == x 1] 1 [binary! concat() f [() [binary! - x 1]]]]]]] [binary! concat() f [() 3]]]]"
      it 'should parse letloop! f = (x) -> if! x==1 1 x+f(x-1) then f(3)', ->
        expect(parse('letloop! f = (x) -> if! x==1 1 x+f(x-1) then f(3)')).to.equal "[[letloop! [[= f [-> [() x] [if! [binary! == x 1] 1 [binary! + x [binary! concat() f [() [binary! - x 1]]]]]]]] [binary! concat() f [() 3]]]]"
      # single \ is invalid escape, will lost
      it '''should parse let a=[\ 1 \] then a[1]''', ->
        x = parse('''let a=[\ 1 \] then a[1]''')
        expect(x).to.equal "[[let [[= a [[] [1]]]] [binary! concat[] a [[] [1]]]]]"
      # data bracket is gone away.
      nit '''should parse let a=[\\ 1 \\] then a[1]''', ->
        x = parse('''let a=[\\ 1 \\] then a[1]''')
        expect(x).to.equal "[[let [[= a [[] [1]]]] [binary! concat[] a [[] 1]]]]"

    describe "indent block: ",  ->
      it 'should parse print \n 1', ->
        expect(parse('print \n 1')).to.equal '[[print 1]]'
      it 'should parse print \n 2 \n 3', ->
        expect(parse('print \n 2 \n 3')).to.equal '[[print 2 3]]'
      it 'should parse print \n abs \n   3', ->
        expect(parse('print \n abs \n   3')).to.equal '[[print [abs 3]]]'
      it 'should parse print \n abs 3 \n abs 4', ->
        expect(parse('print \n abs 3 \n abs 4')).to.equal '[[print [abs 3] [abs 4]]]'
      it 'should parse print : 2', ->
        expect(parse("print : 2")).to.equal '[[print 2]]'

  describe "line: ",  ->
    parse = (text) ->
      parser = new Parser()
      x = parser.parse(text, matchRule(parser, parser.line), 0)
      str x
    it 'should parse print 1 ; print 2', ->
      x = parse('print 1 ; print 2')
      expect(x).to.equal '[[print 1] [print 2]]'
    it 'should parse y+.!1 // y+!1 will be parsed as [+. y 1], so we separate + and ! by "."\n~ print 1', ->
      expect(parse('y+.!1 // y+!1 will be parsed as [+. y 1], so we separate + and ! by "."\n~ print 1')).to.equal "[[binary! + y [prefix! ! 1]]]"

    it 'should parse / print 1 ; print 2', ->
      x = parse('/ print 1 ; print 2')
      expect(x).to.equal "[[codeBlockComment! [[print 1] [print 2]]]]"

    it 'should parse / print \n abs 3 \n abs 4', ->
      expect(parse('/ print \n abs 3 \n abs 4')).to.equal "[[codeBlockComment! [[print [abs 3] [abs 4]]]]]"

    nit 'should parse / try 1 \n  2 \nelse 3', ->
      # es5 does not support try-else
      expect(parse('/ try 1 \n  2 \nelse 3')).to.equal "[[codeBlockComment! [[try [1 2] [list!] 3 undefined]]]]"

    it '''should parse '#a=1;a''', ->
      expect(parse('#a=1;a')).to.equal "[[binary! = [prefix! # a] 1] a]"

    it '''should parse '##a=1;a''', ->
      expect(parse('##a=1;a')).to.equal "[[prefix! ## [binary! = a 1]] a]"

    # \ is escape, will lost in string
    it '''should parse let a=[\ 1 \] then a[1]''', ->
      x = parse('''let a=[\ 1 \] then a[1]''')
      expect(x).to.equal "[[let [[= a [[] [1]]]] [binary! concat[] a [[] [1]]]]]"

  describe "module: ",  ->
    head = 'taiji language 0.1\n'
    parse = (text) ->
      parser = new Parser()
      x = parser.parse(head+text, parser.module, 0)
      str x.value[3]
    describe "misc: ",  ->
      it 'should parse 1', ->
        expect(parse('1 ')).to.equal "[moduleBody! 1]"
      it 'should parse 1.', ->
        expect(parse('1.')).to.equal "[moduleBody! [1 .]]"
      it 'should parse \n1', ->
        expect(parse('\n1 ')).to.equal "[moduleBody! 1]"
      it 'should parse "1"', ->
        expect(parse('"1"')).to.equal "[moduleBody! [string! \"1\"]]"
      it 'should parse a', ->
        expect(parse('a')).to.equal "[moduleBody! a]"
      it 'should parse  print 2', ->
        expect(parse('print 2 ')).to.equal "[moduleBody! [print 2]]"
      it '''should parse '##a=1; # ` ^ a''', ->
        expect(parse('##a=1; # ` ^ a')).to.equal "[moduleBody! [begin! [prefix! ## [binary! = a 1]] [# [` [^ a]]]]]"
      it '''should parse 'a#=1; # ` ^ a''', ->
        expect(parse('a#=1; # ` ^ a')).to.equal "[moduleBody! [begin! [binary! #= a 1] [# [` [^ a]]]]]"
      it '''should parse ^.a''', ->
        expect(parse('^.a')).to.equal "[moduleBody! [prefix! ^ a]]"
      it '''should parse '##a=1; #.`.^a''', ->
        expect(parse('##a=1; #.`.^a')).to.equal "[moduleBody! [begin! [prefix! ## [binary! = a 1]] [prefix! # [prefix! ` [prefix! ^ a]]]]]"
    describe "misc2: ",  ->
      it 'should print \n 2 ', ->
        expect(parse('print \n 2 ')).to.equal "[moduleBody! [print 2]]"
      it 'should  print \n 2 \n 3', ->
        expect(parse('print \n 2 \n 3')).to.equal "[moduleBody! [print 2 3]]"
      it 'should parse  print \n 2  3', ->
        expect(parse('print \n 2  3')).to.equal "[moduleBody! [print [2 3]]]"
      it 'should parse print \n add 1 2; add 3 4', ->
        expect(parse('print \n add 1 2; add 3 4')).to.equal "[moduleBody! [print [add 1 2] [add 3 4]]]"
      it 'should parse /. some comment', ->
        expect(parse('/. some comment')).to.equal "[moduleBody! undefined]"
      it 'should parse 1\n/. some comment', ->
        expect(parse('1\n/. some comment')).to.equal "[moduleBody! 1]"
      it 'should parse /. some \n  embedded \n  comment', ->
        expect(parse('/. some \n  embedded \n  comment')).to.equal "[moduleBody! undefined]"
      it 'should parse ` [ ^1 ^2 ^&[3 4]]', ->
        expect(parse('`[ ^1 ^2 ^&[3 4]]')).to.equal "[moduleBody! [prefix! ` [[] [[[prefix! ^ 1] [prefix! ^ 2] [prefix! ^& [[] [[3 4]]]]]]]]]"
      it 'should parse ` [ ^1 ]', ->
        expect(parse('` [ ^1 ]')).to.equal "[moduleBody! [` [[] [[prefix! ^ 1]]]]]"
      it 'should parse `[ ^1 ]', ->
        expect(parse('`[ ^1 ]')).to.equal "[moduleBody! [prefix! ` [[] [[prefix! ^ 1]]]]]"
      it 'should parse `[ ^1 ^2 ]', ->
        expect(parse('`[ ^1 ^2]')).to.equal "[moduleBody! [prefix! ` [[] [[[prefix! ^ 1] [prefix! ^ 2]]]]]]"
      it 'should parse `{ ^1, ^2 }', ->
        expect(parse('`{ ^1, ^2 }')).to.equal "[moduleBody! [prefix! ` [{} [begin! [prefix! ^ 1] [prefix! ^ 2]]]]]"

    describe "misc3: ",  ->
      it 'should parse # if 0 then 1+2 else 3+4', ->
        expect(parse('# if 0 then 1+2 else 3+4')).to.equal "[moduleBody! [# [if 0 [binary! + 1 2] [binary! + 3 4]]]]"

      it '''should parse [1] ''', ->
        expect(parse('''[1]''')).to.equal "[moduleBody! [[] [1]]]"

      it '''should parse [1, 2] ''', ->
        expect(parse('''[1, 2]''')).to.equal "[moduleBody! [[] [1 2]]]"

      it '''should parse [ 1, 2 ] ''', ->
        expect(parse('''[ 1, 2 ]''')).to.equal "[moduleBody! [[] [1 2]]]"

      it '''should parse [\ 1, 2 \] ''', ->
        expect(parse('''[\ 1, 2 \]''')).to.equal "[moduleBody! [[] [1 2]]]"

      it '''should parse for x in [\ 1, 2 \] then print x''', ->
        expect(parse('''for x in [\ 1, 2 \] then print x''')).to.equal "[moduleBody! [forIn! x undefined [[] [1 2]] [print x]]]"

      it '''should parse for x in [1, 2 ] then print x''', ->
        expect(parse('''for x in [ 1, 2 ] then print x''')).to.equal "[moduleBody! [forIn! x undefined [[] [1 2]] [print x]]]"

      it '''should parse for x in [1 2 ] then print x''', ->
        expect(parse('''for x in [ 1 2 ] then print x''')).to.equal "[moduleBody! [forIn! x undefined [[] [[1 2]]] [print x]]]"

      it '''should parse for x in [ 1 ] then print x''', ->
        expect(parse('''for x in [ 1 ] then print x''')).to.equal "[moduleBody! [forIn! x undefined [[] [1]] [print x]]]"

      it '''should parse for x in [] then print x''', ->
        expect(parse('''for x in [] then print x''')).to.equal "[moduleBody! [forIn! x undefined [[]] [print x]]]"

      it 'should parse {(a,b) -> `( ^a + ^b )}(1,2)', ->
        expect(parse('{(a,b) -> `( ^a + ^b )}(1,2)')).to.equal "[moduleBody! [binary! concat() [{} [-> [() [binary! , a b]] [prefix! ` [() [binary! + [prefix! ^ a] [prefix! ^ b]]]]]] [() [binary! , 1 2]]]]"
      it 'should parse { -> ( a )}()', ->
        expect(parse('{ -> ( a )}()')).to.equal "[moduleBody! [binary! concat() [{} [-> [] [() a]]] [()]]]"
      it 'should parse m #= (a,b) -> `( ^a + ^b); m(1,2)', ->
        expect(parse('m #= (a,b) -> `( ^a + ^b ); m(1,2)')).to.equal "[moduleBody! [#= m [-> [() [binary! , a b]] [begin! [prefix! ` [() [binary! + [prefix! ^ a] [prefix! ^ b]]]] [binary! concat() m [() [binary! , 1 2]]]]]]]"

      it 'should parse switch! 1 {{[2] 3}} 4', ->
        expect(parse("switch! 1 { {[2] 3} } 4")).to.equal "[moduleBody! [switch! 1 [{} [{} [[[] [2]] 3]]] 4]]"

      it '''should parse while! (1) {print 1} ''', ->
        expect(parse('''while! (1) {print 1}''')).to.equal "[moduleBody! [while! [() 1] [{} [print 1]]]]"

      it '''should parse while! (1) ''', ->
        expect(-> parse('''while! (1)''')).to.throw /expect the body for while! statement/

      it '''should parse (1) ''', ->
        expect(parse('''(1)''')).to.equal "[moduleBody! [() 1]]"

    describe "prefix: ",  ->
      it 'should parse +1', ->
        expect(parse('+1 ')).to.equal "[moduleBody! [prefix! + 1]]"
      it 'should parse + 1', ->
        expect(parse('+ 1 ')).to.equal "[moduleBody! [prefix! + 1]]"
      it 'should parse + + 1', ->
        expect(parse('+ + 1 ')).to.equal "[moduleBody! [prefix! + [prefix! + 1]]]"
      it 'should parse print + 1', ->
        expect(parse('print + 1 ')).to.equal "[moduleBody! [binary! + print 1]]"
      it 'should parse print: + 1', ->
        expect(parse('print: + 1 ')).to.equal "[moduleBody! [print [prefix! + 1]]]"

    describe "line and indent operator: ",  ->
      it "parse (1+2\n * 3+6)", ->
        expect(parse('(1+2\n * 3+6)')).to.equal "[moduleBody! [() [binary! * [binary! + 1 2] [binary! + 3 6]]]]"

      it "parse 1+2\n * 3+6\n + 5+8", ->
        expect(parse('(1+2\n * 3+6\n + 5+8)')).to.equal "[moduleBody! [() [binary! * [binary! + 1 2] [binary! + [binary! + 3 6] [binary! + 5 8]]]]]"

      it 'should parse ()', ->
        expect(parse('()').value).to.equal undefined

      it 'should parse ` { ^1 { ^2 ^&{3 4}}}', ->
        expect(parse('`{ ^1 { ^2 ^&{3 4}}}')).to.equal "[moduleBody! [prefix! ` [{} [[prefix! ^ 1] [{} [[prefix! ^ 2] [prefix! ^& [{} [3 4]]]]]]]]]"

      it 'should parse `{ ^1 { ^2 ^&{3 4}}}', ->
        expect(parse('`{ ^1 { ^2 ^&{3 4}}}')).to.equal "[moduleBody! [prefix! ` [{} [[prefix! ^ 1] [{} [[prefix! ^ 2] [prefix! ^& [{} [3 4]]]]]]]]]"

      nit 'should parse letloop! \n  odd = (x) -> if! x==0 0 even(x-1)\n  even = (x) -> if! x==0 1 odd(x-1) \nthen odd(3)', ->
        expect(parse('letloop! \n  odd = (x) -> if! x==0 0 even(x-1)\n  even = (x) -> if! x==0 1 odd(x-1) \nthen odd(3)')).to.equal "[moduleBody! [letloop! [[odd = [-> [() x] [if! [binary! == x 0] 0 [binary! concat() even [() [binary! - x 1]]]]]] [even = [-> [() x] [if! [binary! == x 0] 1 [binary! concat() odd [() [binary! - x 1]]]]]]] [binary! concat() odd [() 3]]]]"

    describe "new parser tests from samples: ",  ->
      it "parse while! 2 if 1 then console.log 1 else console.log 2", ->
        expect(parse('while! 2 if 1 then console.log 1 else console.log 2')).to.equal "[moduleBody! [while! 2 [if 1 [[binary! . console log] 1] [[binary! . console log] 2]]]]"
      it "parse if 1 then 2\nprint 3", ->
        expect(parse('if 1 then 2\nprint 3')).to.equal "[moduleBody! [begin! [if 1 2] [print 3]]]"
      it "parse if 1 then 2 else 3\nprint 4", ->
        expect(parse('if 1 then 2 else 3\nprint 4')).to.equal "[moduleBody! [begin! [if 1 2 3] [print 4]]]"
      it "parse while! 1 2 \nwhile! 3 4", ->
        expect(parse('while! 1 2 \nwhile! 3 4')).to.equal "[moduleBody! [begin! [while! 1 2] [while! 3 4]]]"
      it "parse while! 1 if 2 then 3 \nprint 4", ->
        expect(parse('while! 1 if 2 then 3 \nprint 4')).to.equal "[moduleBody! [begin! [while! 1 [if 2 3]] [print 4]]]"
      it "parse while! 2 if 1 then console.log 1 else console.log 2\nwhile! 3\n if 1 then console.log 1 else console.log 2", ->
        expect(parse('while! 2 if 1 then console.log 1 else console.log 2\nwhile! 3\n if 1 then console.log 1 else console.log 2')).to.equal "[moduleBody! [begin! [while! 2 [if 1 [[binary! . console log] 1] [[binary! . console log] 2]]] [while! 3 [if 1 [[binary! . console log] 1] [[binary! . console log] 2]]]]]"
      it "parse var a=1, b=2", ->
        expect(parse('var a=1, b=2')).to.equal "[moduleBody! [var [= a 1] [= b 2]]]"

      it '''should parse try! {throw 3} e {print 1} {print 'finally here'}''', ->
        expect(parse("var e\ntry! {throw 3} e {print 1} {print 'finally here'}")).to.equal "[moduleBody! [begin! [var e] [try! [{} [throw 3]] e [{} [print 1]] [{} [print \"finally here\"]]]]]"

      it 'should parse console.log : and 1 2', ->
        x = parse('console.log : and 1 2')
        expect(x).to.deep.equal "[moduleBody! [[binary! . console log] [and 1 2]]]"

      it 'should parse and 1 /* inline comment */ 2', ->
        x = parse('and 1 /* inline comment */ 2')
        expect(x).to.deep.equal "[moduleBody! [and 1 2]]"

    describe "new parser tests from samples 2: ",  ->
      it 'should parse and 1 /* inline \ncomment */ 2', ->
        x = parse('and 1 /* inline \ncomment */ 2')
        expect(x).to.deep.equal "[moduleBody! [and 1 2]]"

      it 'should parse and 1/* inline comment */2', ->
        x = parse('and 1/* inline comment */2')
        expect(x).to.deep.equal "[moduleBody! [and 1 2]]"

      it 'should parse and\n 1\n/* comment */', ->
        x = parse('and\n 1\n/* comment */')
        expect(x).to.deep.equal "[moduleBody! [and 1]]"

      it 'should parse x = ->\n 1\n/* comment */', ->
        x = parse('x = ->\n 1\n/* comment */')
        expect(x).to.deep.equal "[moduleBody! [= x [-> [] 1]]]"

      it 'should parse x = /!-h\b|-r\b|-v\b|-b\b/', ->
        x = parse('x = /!-h\b|-r\b|-v\b|-b\b/')
        expect(x).to.deep.equal "[moduleBody! [= x [regexp! /-h\b|-r\b|-v\b|-b\b/]]]"

      it 'should parse a = 2\nx = : 1', ->
        expect(-> parse('a = 2\nx = : 1')).to.throw /expect the right side of assign/

      it 'should parse a = 2\nx = 1', ->
        expect(parse('a = 2\nx = 1')).to.equal "[moduleBody! [begin! [= a 2] [= x 1]]]"

      it 'should parse error: 1', ->
        x = parse('error: 1 ')
        expect(x).to.deep.equal "[moduleBody! [error 1]]"

      it 'should parse error: new: Error "Error: No Input file given" ', ->
        x = parse('error: new: Error "Error: No Input file given" ')
        expect(x).to.deep.equal "[moduleBody! [error [new [Error [string! \"Error: No Input file given\"]]]]]"

      it 'should parse new : Error', ->
        x = parse('new : Error')
        expect(x).to.deep.equal "[moduleBody! [new Error]]"

      it 'should parse new: Error "Error: No Input file given" ', ->
        x = parse('new : Error "Error: No Input file given"')
        expect(x).to.deep.equal "[moduleBody! [new [Error [string! \"Error: No Input file given\"]]]]"

      it 'should parse x {. a: b }', ->
        expect(parse('x {. a: b }')).to.equal "[moduleBody! [x [hash! [jshashitem! a b]]]]"

      it 'should parse node.spawn outfile() {.stdio: "inherit" }', ->
          expect(parse('node.spawn outfile() {.stdio: "inherit" }')).to.equal "[moduleBody! [[binary! . node spawn] [binary! concat() outfile [()]] [hash! [jshashitem! stdio [string! \"inherit\"]]]]]"

    describe "indented string block: ",  ->
      it 'should parse indented string ', ->
        code = '''var a = '
          a abbr address
          caption cite' '''
        x = parse(code)
        expect(x).to.deep.equal "[moduleBody! [var [= a \"\\na abbr address\\ncaption cite\"]]]"

      it 'should parse assign a indented string ', ->
        code = '''a = '
          a abbr address
          caption cite' '''
        x = parse(code)
        expect(x).to.deep.equal "[moduleBody! [= a \"\\na abbr address\\ncaption cite\"]]"

      it 'should parse indented string which start by space ', ->
        # the first line is indented by a space , so it is a part of module head, not the program body.
        code = ''' var a = '
          a abbr address
          caption cite' '''
        expect(-> parse(code)).to.throw /unexpected end of input/

    describe "import module: ",  ->
      it '''should parse import! a as A, #b as #b from 'x.tj' as x''', ->
        code = '''import! a as A, #b as #b from 'x.tj' as x '''
        x = parse(code)
        expect(x).to.deep.equal "[moduleBody! [import! \"x.tj\" undefined x undefined [[a A]] [[b b meta]]]]"
      it '''should parse import! a as A, #b as #b from 'x.tj' as #/x''', ->
        code = '''import! a as A, #b as #b from 'x.tj' as #/x '''
        x = parse(code)
        expect(x).to.deep.equal "[moduleBody! [import! \"x.tj\" undefined x x [[a A]] [[b b meta]]]]"
      it '''should parse import! a as A, #b from 'x.tj' as x''', ->
        code = '''import! a as A, #b from 'x.tj' as x '''
        x = parse(code)
        expect(x).to.deep.equal "[moduleBody! [import! \"x.tj\" undefined x undefined [[a A]] [[b b meta]]]]"
      it '''should parse import! a as A, #/b from 'x.tj' as x''', ->
        code = '''import! a as A, #/b from 'x.tj' as x '''
        x = parse(code)
        expect(x).to.deep.equal "[moduleBody! [import! \"x.tj\" undefined x undefined [[a A] [b b]] [[b b meta]]]]"
      it "should parse import! #/b as b1 #b2 from 'x.tj'", ->
        code = "import! #/b as b1 #b2 from 'x.tj'"
        x = parse(code)
        expect(x).to.deep.equal "[moduleBody! [import! \"x.tj\" undefined undefined undefined [[b b1]] [[b b2 meta]]]]"
      it '''should parse import! a as A, #/b as b1 #b2 from 'x.tj' as x''', ->
        code = '''import! a as A, #/b as b1 #b2 from 'x.tj' as x '''
        x = parse(code)
        expect(x).to.deep.equal "[moduleBody! [import! \"x.tj\" undefined x undefined [[a A] [b b1]] [[b b2 meta]]]]"
      it '''should parse import! x''', ->
        code = '''import! 'x.tj' '''
        x = parse(code)
        expect(x).to.deep.equal "[moduleBody! [import! \"x.tj\" undefined undefined undefined [] []]]"

    describe "export!: ",  ->
      it '''should parse export! a = A, #b, c, #b = d''', ->
        code = '''export! a = A, #b, c, #b = d '''
        x = parse(code)
        expect(x).to.deep.equal "[moduleBody! [export! [a A runtime undefined] [b undefined undefined meta] [c undefined runtime undefined] [b d undefined meta] undefined]]"

    describe "assign to outer scope var: ",  ->
      it "should parse @@a", ->
        expect(parse('@@a')).to.equal "[moduleBody! [prefix! @@ a]]"
      it "should parse @@a+1", ->
        expect(parse('@@a+1')).to.equal "[moduleBody! [binary! + [prefix! @@ a] 1]]"
      it "should parse a=1; -> @@a=1", ->
        expect(parse('a=1; -> @@a=1')).to.equal "[moduleBody! [begin! [binary! = a 1] [-> [] [binary! = [prefix! @@ a] 1]]]]"

    it 'should parse if! 1 {break} {continue}', ->
      expect(parse("if! 1 {break} {continue}")).to.equal "[moduleBody! [if! 1 [{} [break]] [{} [continue]]]]"

    it 'should parse [1 2]', ->
      expect(parse("[1 2]")).to.equal "[moduleBody! [[] [[1 2]]]]"

    it 'should parse [1, 2]', ->
      expect(parse("[1, 2]")).to.equal "[moduleBody! [[] [1 2]]]"