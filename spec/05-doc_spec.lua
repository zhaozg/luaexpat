local doc = require 'lxp.doc'


describe("lxp:doc", function()


	it("new() creates a doc", function()
		local d = doc.new 'top':addtag 'child':text 'alice':up():addtag 'child':text 'bob'
		assert(type(d) == 'table')

		local s = doc.tostring(d, '', '  ')
		assert(type(s) == 'string')
	end)

	it("compare a doc", function()
		local d = doc.new 'children':
			addtag 'child':
			addtag 'name':text 'alice':up():addtag 'age':text '5':up():addtag('toy', { type = 'fluffy' }):up():
			up():
			addtag 'child':
			addtag 'name':text 'bob':up():addtag 'age':text '6':up():addtag('toy', { type = 'squeaky' })

		--~ pretty_print(d)

		local children, child, toy, name, age = doc.tags 'children,child,toy,name,age'

		local d1 = children {
			child { name 'alice', age '5', toy { type = 'fluffy' } },
			child { name 'bob', age '6', toy { type = 'squeaky' } }
		}

		--~ pretty_print(d1)
		assert(doc.compare(d, d1))

		local templ = child { name '$name', age '$age', toy { type = '$toy' } }

		local d2 = children(templ:subst {
			{ name = 'alice', age = '5', toy = 'fluffy' },
			{ name = 'bob', age = '6', toy = 'squeaky' }
		})

		assert(doc.compare(d1, d2))

		local i = 0
		doc.walk(d2, false, function(tag, v)
			i = i + 1
			assert(tag)
			assert(v)
		end)

		i = 0
		for c in d2:childtags() do i = i + 1 end
		assert(i > 0)

		local d3 = templ:subst(
			{ name = 'jane', age = '7', toy = 'wobbly' }
		)
		assert(type(d3) == 'table')
	end)

end)
