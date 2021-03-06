/*******************************************************************************

        Copyright:
            Copyright (c) 2008 Jeff Davey.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Standards: rfc3548, rfc2045

        Authors: Jeff Davey

*******************************************************************************/

/*******************************************************************************

    This module is used to decode and encode base64 char[] arrays.

    Example:
    ---
    istring blah = "Hello there, my name is Jeff.";
    scope encodebuf = new char[allocateEncodeSize(cast(ubyte[])blah)];
    mstring encoded = encode(cast(ubyte[])blah, encodebuf);

    scope decodebuf = new ubyte[encoded.length];
    if (cast(cstring)decode(encoded, decodebuf) == "Hello there, my name is Jeff.")
        Stdout("yay").newline;
    ---

*******************************************************************************/

module ocean.util.encode.Base64;

import ocean.transition;

version (UnitTest) import ocean.core.Test;

/*******************************************************************************

    calculates and returns the size needed to encode the length of the
    array passed.

    Params:
    data = An array that will be encoded

*******************************************************************************/


size_t allocateEncodeSize(in ubyte[] data)
{
    return allocateEncodeSize(data.length);
}

/*******************************************************************************

    calculates and returns the size needed to encode the length passed.

    Params:
    length = Number of bytes to be encoded

*******************************************************************************/

size_t allocateEncodeSize(size_t length)
{
    size_t tripletCount = length / 3;
    size_t tripletFraction = length % 3;
    return (tripletCount + (tripletFraction ? 1 : 0)) * 4; // for every 3 bytes we need 4 bytes to encode, with any fraction needing an additional 4 bytes with padding
}


/*******************************************************************************

    encodes data into buff and returns the number of bytes encoded.
    this will not terminate and pad any "leftover" bytes, and will instead
    only encode up to the highest number of bytes divisible by three.

    returns the number of bytes left to encode

    Params:
    data = what is to be encoded
    buff = buffer large enough to hold encoded data
    bytesEncoded = ref that returns how much of the buffer was filled

*******************************************************************************/

int encodeChunk(in ubyte[] data, mstring buff, ref int bytesEncoded)
{
    size_t tripletCount = data.length / 3;
    int rtn = 0;
    char *rtnPtr = buff.ptr;
    Const!(ubyte) *dataPtr = data.ptr;

    if (data.length > 0)
    {
        rtn = cast(int) tripletCount * 3;
        bytesEncoded = cast(int) tripletCount * 4;
        for (size_t i; i < tripletCount; i++)
        {
            *rtnPtr++ = _encodeTable[((dataPtr[0] & 0xFC) >> 2)];
            *rtnPtr++ = _encodeTable[(((dataPtr[0] & 0x03) << 4) | ((dataPtr[1] & 0xF0) >> 4))];
            *rtnPtr++ = _encodeTable[(((dataPtr[1] & 0x0F) << 2) | ((dataPtr[2] & 0xC0) >> 6))];
            *rtnPtr++ = _encodeTable[(dataPtr[2] & 0x3F)];
            dataPtr += 3;
        }
    }

    return rtn;
}

/*******************************************************************************

    encodes data and returns as an ASCII base64 string.

    Params:
    data = what is to be encoded
    buff = buffer large enough to hold encoded data

    Example:
    ---
    char[512] encodebuf;
    char[] myEncodedString = encode(cast(ubyte[])"Hello, how are you today?", encodebuf);
    Stdout(myEncodedString).newline; // SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==
    ---


*******************************************************************************/

mstring encode(in ubyte[] data, mstring buff)
in
{
    assert(data);
    assert(buff.length >= allocateEncodeSize(data));
}
body
{
    mstring rtn = null;

    if (data.length > 0)
    {
        int bytesEncoded = 0;
        int numBytes = encodeChunk(data, buff, bytesEncoded);
        char *rtnPtr = buff.ptr + bytesEncoded;
        Const!(ubyte)* dataPtr = data.ptr + numBytes;
        auto tripletFraction = data.length - (dataPtr - data.ptr);

        switch (tripletFraction)
        {
            case 2:
                *rtnPtr++ = _encodeTable[((dataPtr[0] & 0xFC) >> 2)];
                *rtnPtr++ = _encodeTable[(((dataPtr[0] & 0x03) << 4) | ((dataPtr[1] & 0xF0) >> 4))];
                *rtnPtr++ = _encodeTable[((dataPtr[1] & 0x0F) << 2)];
                *rtnPtr++ = '=';
                break;
            case 1:
                *rtnPtr++ = _encodeTable[((dataPtr[0] & 0xFC) >> 2)];
                *rtnPtr++ = _encodeTable[((dataPtr[0] & 0x03) << 4)];
                *rtnPtr++ = '=';
                *rtnPtr++ = '=';
                break;
            default:
                break;
        }
        rtn = buff[0..(rtnPtr - buff.ptr)];
    }

    return rtn;
}

/*******************************************************************************

    encodes data and returns as an ASCII base64 string.

    Params:
    data = what is to be encoded

    Example:
    ---
    mstring myEncodedString = encode(cast(ubyte[])"Hello, how are you today?");
    Stdout(myEncodedString).newline; // SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==
    ---


*******************************************************************************/


mstring encode(in ubyte[] data)
in
{
    assert(data);
}
body
{
    auto rtn = new char[allocateEncodeSize(data)];
    return encode(data, rtn);
}

/*******************************************************************************

    decodes an ASCCI base64 string and returns it as ubyte[] data. Pre-allocates
    the size of the array.

    This decoder will ignore non-base64 characters. So:
    SGVsbG8sIGhvd
    yBhcmUgeW91IH
    RvZGF5Pw==

    Is valid.

    Params:
    data = what is to be decoded

    Example:
    ---
    char[] myDecodedString = cast(char[])decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
    Stdout(myDecodedString).newline; // Hello, how are you today?
    ---

*******************************************************************************/

ubyte[] decode(cstring data)
in
{
    assert(data);
}
body
{
    auto rtn = new ubyte[data.length];
    return decode(data, rtn);
}

/*******************************************************************************

    decodes an ASCCI base64 string and returns it as ubyte[] data.

    This decoder will ignore non-base64 characters. So:
    SGVsbG8sIGhvd
    yBhcmUgeW91IH
    RvZGF5Pw==

    Is valid.

    Params:
    data = what is to be decoded
    buff = a big enough array to hold the decoded data

    Example:
    ---
    ubyte[512] decodebuf;
    char[] myDecodedString = cast(char[])decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==", decodebuf);
    Stdout(myDecodedString).newline; // Hello, how are you today?
    ---

*******************************************************************************/

ubyte[] decode(cstring data, ubyte[] buff)
in
{
    assert(data);
}
body
{
    ubyte[] rtn;

    if (data.length > 0)
    {
        ubyte[4] base64Quad;
        ubyte *quadPtr = base64Quad.ptr;
        ubyte *endPtr = base64Quad.ptr + 4;
        ubyte *rtnPt = buff.ptr;
        size_t encodedLength = 0;

        ubyte padCount = 0;
        ubyte endCount = 0;
        ubyte paddedPos = 0;
        foreach_reverse(char piece; data)
        {
            paddedPos++;
            ubyte current = _decodeTable[piece];
            if (current || piece == 'A')
            {
                endCount++;
                if (current == BASE64_PAD)
                    padCount++;
            }
            if (endCount == 4)
                break;
        }

        if (padCount > 2)
            throw new Exception("Improperly terminated base64 string. Base64 pad character (=) found where there shouldn't be one.");
        if (padCount == 0)
            paddedPos = 0;

        auto nonPadded = data[0..($ - paddedPos)];
        foreach(piece; nonPadded)
        {
            ubyte next = _decodeTable[piece];
            if (next || piece == 'A')
                *quadPtr++ = next;
            if (quadPtr is endPtr)
            {
                rtnPt[0] = cast(ubyte) ((base64Quad[0] << 2) | (base64Quad[1] >> 4));
                rtnPt[1] = cast(ubyte) ((base64Quad[1] << 4) | (base64Quad[2] >> 2));
                rtnPt[2] = cast(ubyte) ((base64Quad[2] << 6) | base64Quad[3]);
                encodedLength += 3;
                quadPtr = base64Quad.ptr;
                rtnPt += 3;
            }
        }

        // this will try and decode whatever is left, even if it isn't terminated properly (ie: missing last one or two =)
        if (paddedPos)
        {
            auto padded = data[($ - paddedPos) .. $];
            foreach(char piece; padded)
            {
                ubyte next = _decodeTable[piece];
                if (next || piece == 'A')
                    *quadPtr++ = next;
                if (quadPtr is endPtr)
                {
                    *rtnPt++ = cast(ubyte) (((base64Quad[0] << 2) | (base64Quad[1]) >> 4));
                    if (base64Quad[2] != BASE64_PAD)
                    {
                        *rtnPt++ = cast(ubyte) (((base64Quad[1] << 4) | (base64Quad[2] >> 2)));
                        encodedLength += 2;
                        break;
                    }
                    else
                    {
                        encodedLength++;
                        break;
                    }
                }
            }
        }

        rtn = buff[0..encodedLength];
    }

    return rtn;
}


unittest
{
    istring str = "Hello, how are you today?";
    Const!(ubyte)[] payload = cast(Const!(ubyte)[]) str;

    // encodeChunktest
    {
        mstring encoded = new char[allocateEncodeSize(payload)];
        int bytesEncoded = 0;
        int numBytesLeft = encodeChunk(payload, encoded, bytesEncoded);
        cstring result = encoded[0..bytesEncoded] ~ encode(payload[numBytesLeft..$], encoded[bytesEncoded..$]);
        test!("==")(result, "SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
    }

    // encodeTest
    {
        mstring encoded = new char[allocateEncodeSize(payload)];
        cstring result = encode(payload, encoded);
        test!("==")(result, "SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");

        cstring result2 = encode(payload);
        test!("==")(result, "SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
    }

    // decodeTest
    {
        ubyte[1024] decoded;
        ubyte[] result = decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==", decoded);
        test!("==")(result, payload);
        result = decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
        test!("==")(result, payload);
    }
}


private:

/*
    Static immutable tables used for fast lookups to
    encode and decode data.
*/
const ubyte BASE64_PAD = 64;
static istring _encodeTable = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

static Const!(ubyte)[] _decodeTable = [
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,62,0,0,0,63,52,53,54,55,56,57,58,
    59,60,61,0,0,0,BASE64_PAD,0,0,0,0,1,2,3,
    4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,
    19,20,21,22,23,24,25,0,0,0,0,0,0,26,27,
    28,29,30,31,32,33,34,35,36,37,38,39,40,
    41,42,43,44,45,46,47,48,49,50,51,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0
];
