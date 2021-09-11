
/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/* This is the D syntax highligher.
 */

module syntaxd;

import core.stdc.stdio;
import core.stdc.ctype;

import std.utf;

import ed;
import buffer;
import window;
import main;
import display;
import random;

/********************************
 * Returns:
 *	starting syntax state of next line
 */
SyntaxState syntaxHighlightD(SyntaxState syntaxState, const(char)[] text, attr_t[] attr)
{
    size_t i = 0;

    switch (syntaxState.syntax)
    {
	case Syntax.string:
	case Syntax.singleString:
	case Syntax.backtickString:
	{
	    const quote = (syntaxState.syntax == Syntax.string)       ? '"' :
			  (syntaxState.syntax == Syntax.singleString) ? '\'' :
			                                                '`';
	    const istart = i;
	    bool escape;
	    while (i < text.length)
	    {
		if (text[i] == quote && !escape)
		{
		    ++i;
		    attr[istart .. i] = config.string;
		    goto Loop;
		}
		else if (text[i] == '\\')
		    escape ^= true;
		else
		    escape = false;
		++i;
	    }
	    attr[istart .. i] = config.string;
	    return SyntaxState(syntaxState.syntax);
	}

	case Syntax.comment:
	{
	    if (syntaxState.nest)	// it's /+ +/ nested comment
	    {
		const istart = i;
		uint nest = syntaxState.nest;
		while (i < text.length)
		{
		    if (text[i] == '+' && i + 1 < text.length && text[i + 1] == '/')
		    {
			i += 2;
			--nest;
			if (nest == 0)
			{
			    attr[istart .. i] = config.comment;
			    goto Loop;
			}
			continue;
		    }
		    if (text[i] == '/' && i + 1 < text.length && text[i + 1] == '+')
		    {
			i += 2;
			++nest;
			continue;
		    }
		    ++i;
		}
		attr[istart .. i] = config.comment;
		return SyntaxState(Syntax.comment, nest);
	    }
	    else			// it's /* */ comment
	    {
		const istart = i;
		while (i < text.length)
		{
		    if (text[i] == '*' && i + 1 < text.length && text[i + 1] == '/')
		    {
			i += 2;
			attr[istart .. i] = config.comment;
			goto Loop;
		    }
		    ++i;
		}
		attr[istart .. i] = config.comment;
		return SyntaxState(Syntax.comment);
	    }
	}

	default:
	    break;
    }

  Loop:
    while (i < text.length)
    {
	const c = text[i];
	switch (c)
	{
	    case 'a': .. case 'z':
	    case 'A': .. case 'Z':
	    case '_':
	    Idstart:
	    {
		const istart = i;
		++i;
		while (i < text.length)
		{
		    const ci = text[i];
		    if (isalnum(ci) || ci == '_' || ci & 0x80)
		    {
			++i;
			continue;
		    }
		    break;
		}
		const id = text[istart .. i];
		attr[istart .. i] = isKeyword(id) ? config.keyword : config.normattr;
		continue;
	    }

	    case '/':
	    {
		const istart = i;
		++i;
		if (i < text.length)
		{
		    if (text[i] == '/')
		    {
			attr[istart .. text.length] = config.comment;
			return SyntaxState(Syntax.normal);
		    }

		    if (text[i] == '*')
		    {
			++i;
			while (i < text.length)
			{
			    if (text[i] == '*' && i + 1 < text.length && text[i + 1] == '/')
			    {
				i += 2;
				attr[istart .. i] = config.comment;
				continue Loop;
			    }
			    ++i;
			}
			attr[istart .. i] = config.comment;
			return SyntaxState(Syntax.comment);
		    }

		    if (text[i] == '+')
		    {
			uint nest = 1;
			++i;
			while (i < text.length)
			{
			    if (text[i] == '+' && i + 1 < text.length && text[i + 1] == '/')
			    {
				i += 2;
				--nest;
				if (nest == 0)
				{
				    attr[istart .. i] = config.comment;
				    continue Loop;
				}
				continue;
			    }
			    if (text[i] == '/' && i + 1 < text.length && text[i + 1] == '+')
			    {
				i += 2;
				++nest;
				continue;
			    }
			    ++i;
			}
			attr[istart .. i] = config.comment;
			return SyntaxState(Syntax.comment, nest);
		    }
		}
		continue;
	    }

	    case '"':
	    case '\'':
	    case '`':
	    {
		const istart = i;
		bool escape;
		++i;
		while (i < text.length)
		{
		    if (text[i] == c && !escape)
		    {
			++i;
			attr[istart .. i] = config.string;
			continue Loop;
		    }
		    else if (text[i] == '\\')
			escape ^= true;
		    else
			escape = false;
		    ++i;
		}
		attr[istart .. i] = config.string;
		return SyntaxState(c == '"'  ? Syntax.string :
				   c == '\'' ? Syntax.singleString :
				               Syntax.backtickString);
	    }

	    default:
		if (text[i] & 0x80)
		    goto Idstart;
		attr[i] = config.normattr;
		++i;
		continue;
	}
/*
	switch (syntaxState.syntax)
	{
	    case Syntax.normal:
		break;

	    case Syntax.string:
	    case Syntax.singleString:
		break;

	    case Syntax.comment:
		break;

	    default:
		assert(0);
	}
*/
    }
    return SyntaxState(Syntax.normal);
}

bool isKeyword(const(char)[] s)
{
    switch (s)
    {
        case "this":
        case "super":
        case "assert":
        case "null":
        case "true":
        case "false":
        case "cast":
        case "new":
        case "delete":
        case "throw":
        case "module":
        case "pragma":
        case "typeof":
        case "typeid":
        case "template":
        case "void":
        case "byte":
        case "ubyte":
        case "short":
        case "ushort":
        case "int":
        case "uint":
        case "long":
        case "ulong":
        case "cent":
        case "ucent":
        case "float":
        case "double":
        case "real":
        case "bool":
        case "char":
        case "wchar":
        case "dchar":
        case "ifloat":
        case "idouble":
        case "ireal":
        case "cfloat":
        case "cdouble":
        case "creal":
        case "delegate":
        case "function":
        case "is":
        case "if":
        case "else":
        case "while":
        case "for":
        case "do":
        case "switch":
        case "case":
        case "default":
        case "break":
        case "continue":
        case "synchronized":
        case "return":
        case "goto":
        case "try":
        case "catch":
        case "finally":
        case "with":
        case "asm":
        case "foreach":
        case "foreach_reverse":
        case "scope":
        case "struct":
        case "class":
        case "interface":
        case "union":
        case "enum":
        case "import":
        case "mixin":
        case "static":
        case "final":
        case "const":
        case "alias":
        case "override":
        case "abstract":
        case "debug":
        case "deprecated":
        case "in":
        case "out":
        case "inout":
        case "lazy":
        case "auto":
        case "align":
        case "extern":
        case "private":
        case "package":
        case "protected":
        case "public":
        case "export":
        case "invariant":
        case "unittest":
        case "version":
        case "__argTypes":
        case "__parameters":
        case "ref":
        case "macro":
        case "pure":
        case "nothrow":
        case "__gshared":
        case "__traits":
        case "__vector":
        case "__overloadset":
        case "__FILE__":
        case "__FILE_FULL_PATH__":
        case "__LINE__":
        case "__MODULE__":
        case "__FUNCTION__":
        case "__PRETTY_FUNCTION__":
        case "shared":
        case "immutable":
	    return true;

	default:
	    return false;
    }
}
