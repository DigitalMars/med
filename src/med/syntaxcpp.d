
/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/* This is the C++ syntax highligher.
 */

module syntaxcpp;

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
SyntaxState syntaxHighlightCPP(SyntaxState syntaxState, const(char)[] text, attr_t[] attr)
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
                attr[istart .. i] = isCPPKeyword(id) ? config.keyword : config.normattr;
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

private bool isCPPKeyword(const(char)[] s)
{
    switch (s)
    {
        case "alignas":
        case "const_cast":
        case "for":
        case "public":
        case "thread_local ":
        case "alignof":
        case "continue":
        case "friend":
        case "register":
        case "throw":
        case "asm":
        case "decltype":
        case "goto":
        case "reinterpret_cast":
        case "true ":
        case "auto":
        case "default":
        case "if":
        case "requires":
        case "try ":
        case "bool":
        case "delete":
        case "inline":
        case "return":
        case "typedef ":
        case "break":
        case "do":
        case "int":
        case "short":
        case "typeid ":
        case "case":
        case "double":
        case "long":
        case "signed":
        case "typename ":
        case "catch":
        case "dynamic_cast":
        case "mutable":
        case "sizeof":
        case "union ":
        case "char":
        case "else":
        case "namespace":
        case "static":
        case "unsigned ":
        case "char16_t":
        case "enum":
        case "new":
        case "static_assert":
        case "using ":
        case "char32_t":
        case "explicit":
        case "noexcept":
        case "static_cast":
        case "virtual ":
        case "class":
        case "export":
        case "nullptr":
        case "struct":
        case "void ":
        case "concept":
        case "extern":
        case "operator":
        case "switch":
        case "volatile ":
        case "const":
        case "false":
        case "private":
        case "template":
        case "wchar_t ":
        case "constexpr":
        case "float":
        case "protected":
        case "this":
        case "while":

        case "and":
        case "and_eq":
        case "bitand":
        case "bitor":
        case "compl":
        case "not ":
        case "not_eq":
        case "or":
        case "or_eq":
        case "xor":
        case "xor_eq ":

        case "__FILE__":
        case "__LINE__":
            return true;

        default:
            return false;
    }
}
