
/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/* This is the C syntax highligher.
 */

module syntaxc;

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
 *      starting syntax state of next line
 */
SyntaxState syntaxHighlightC(SyntaxState syntaxState, const(char)[] text, attr_t[] attr)
{
    size_t i = 0;

    switch (syntaxState.syntax)
    {
        case Syntax.string:
        case Syntax.singleString:
        {
            const quote = (syntaxState.syntax == Syntax.string)       ? '"' :
                                                                        '\'';
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
            // it's /* */ comment
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
                attr[istart .. i] = isCKeyword(id) ? config.keyword : config.normattr;
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
                }
                continue;
            }

            case '"':
            case '\'':
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
                                               Syntax.singleString);
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

private bool isCKeyword(const(char)[] s)
{
    switch (s)
    {
        case "break":
        case "inline":
        case "void":
        case "case":
        case "if":
        case "int":
        case "volatile":
        case "char":
        case "long":
        case "while ":
        case "const":
        case "register":
        case "continue":
        case "restrict":
        case "default":
        case "return":
        case "do":
        case "short":
        case "double":
        case "signed":
        case "else":
        case "sizeof":
        case "enum":
        case "static":
        case "extern":
        case "struct":
        case "float":
        case "switch":
        case "for":
        case "typedef":
        case "goto":
        case "union ":
        case "_Alignas ":
        case "_Alignof ":
        case "_Atomic ":
        case "_Bool ":
        case "_Complex ":
        case "_Generic ":
        case "_Imaginary ":
        case "_Noreturn ":
        case "_Static_assert ":
        case "_Thread_local ":
        case "__FILE__":
        case "__LINE__":
            return true;

        default:
            return false;
    }
}
