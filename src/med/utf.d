

/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://dlang.org
 * This program is in the public domain.
 * https://github.com/DigitalMars/med/blob/master/src/med/uni.d
 */

/******************************************
 * Decode Unicode character from UTF-8 string.
 * Advance index to be past decoded character.
 * Treat errors as if the first code unit is valid.
 * Params:
 *      s = UTF-8 string to decode
 *      index = index into s[] to start decoding, index is updated on return
 * Returns:
 *      decoded character
 */
dchar decodeUTF8(const(char)[] s, ref size_t index)
{
    const i = index;
    const c = s[i];
    if (c <= 0x7F)
    {
  Lerr:
        index = i + 1;
        return c;
    }

    /* The following encodings are valid, except for the 5 and 6 byte
     * combinations:
     *      0xxxxxxx
     *      110xxxxx 10xxxxxx
     *      1110xxxx 10xxxxxx 10xxxxxx
     *      11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
     *      111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
     *      1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
     */
    uint n;
    for (n = 1; ; ++n)
    {
        if (n > 4)
            goto Lerr;              // only do the first 4 of 6 encodings
        if (((c << n) & 0x80) == 0)
        {
            if (n == 1)
                goto Lerr;
            break;
        }
    }

    // Pick off (7 - n) significant bits of first byte of octet
    auto V = cast(dchar)(c & ((1 << (7 - n)) - 1));

    if (i + (n - 1) >= s.length)
        goto Lerr;                  // off end of string

    /* The following combinations are overlong, and illegal:
     *      1100000x (10xxxxxx)
     *      11100000 100xxxxx (10xxxxxx)
     *      11110000 1000xxxx (10xxxxxx 10xxxxxx)
     *      11111000 10000xxx (10xxxxxx 10xxxxxx 10xxxxxx)
     *      11111100 100000xx (10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx)
     */
    const c2 = s[i + 1];
    if ((c & 0xFE) == 0xC0 ||
        (c == 0xE0 && (c2 & 0xE0) == 0x80) ||
        (c == 0xF0 && (c2 & 0xF0) == 0x80) ||
        (c == 0xF8 && (c2 & 0xF8) == 0x80) ||
        (c == 0xFC && (c2 & 0xFC) == 0x80))
        goto Lerr;                  // overlong combination

    for (uint j = 1; j != n; ++j)
    {
        const u = s[i + j];
        if ((u & 0xC0) != 0x80)
            goto Lerr;                      // trailing bytes are 10xxxxxx
        V = (V << 6) | (u & 0x3F);
    }
    if (!isValidDchar(V))
        goto Lerr;
    index = i + n;
    return V;
}

bool isValidDchar(dchar c)
{
    return c < 0xD800 ||
        (c > 0xDFFF && c <= 0x10FFFF && c != 0xFFFE && c != 0xFFFF);
}

/********************************************
 * Backup in string. The reverse of decodeUTF8().
 */

dchar decodeUTF8back(const(char)[] s, ref size_t index)
{
    const i = index;
    if (!i)
        return 0;

    const c = s[i];
    if (c <= 0x7F)
    {
      Lerr:
        index = i - 1;
        return c;
    }

    uint n;
    for (size_t j = i; 1; )
    {
        if (j == 1 || i - j == 4)
            goto Lerr;
        --j;
        auto u = s[j];
        if (u <= 0x7F)
            goto Lerr;
        if ((u & 0xC0) == 0xC0)
        {
            index = j;
            return 0;
        }
    }
    assert(0);
}

enum dchar replacementDchar = '\uFFFD';

char[] toUTF8(return out char[4] buf, dchar c) nothrow @nogc @safe
{
    if (c <= 0x7F)
    {
        buf[0] = cast(char)c;
        return buf[0 .. 1];
    }
    else if (c <= 0x7FF)
    {
        buf[0] = cast(char)(0xC0 | (c >> 6));
        buf[1] = cast(char)(0x80 | (c & 0x3F));
        return buf[0 .. 2];
    }
    else if (c <= 0xFFFF)
    {
        if (c >= 0xD800 && c <= 0xDFFF)
            c = replacementDchar;

    L3:
        buf[0] = cast(char)(0xE0 | (c >> 12));
        buf[1] = cast(char)(0x80 | ((c >> 6) & 0x3F));
        buf[2] = cast(char)(0x80 | (c & 0x3F));
        return buf[0 .. 3];
    }
    else
    {
        if (c > 0x10FFFF)
        {
            c = replacementDchar;
            goto L3;
        }

        buf[0] = cast(char)(0xF0 | (c >> 18));
        buf[1] = cast(char)(0x80 | ((c >> 12) & 0x3F));
        buf[2] = cast(char)(0x80 | ((c >> 6) & 0x3F));
        buf[3] = cast(char)(0x80 | (c & 0x3F));
        return buf[0 .. 4];
    }
}
