using Godot;
using GDictionary = Godot.Collections.Dictionary;
using System;
using System.Numerics;
using System.Collections.Generic;



public partial class babel_math : Node
{
    private static Node global_values;

    private static string     cachedHex      = "";
    private static BigInteger cachedHexValue = BigInteger.Zero;

    private static string     cachedBookKey   = "";
    private static BigInteger cachedBookValue = BigInteger.Zero;

    private static readonly char[] Base29Characters = {
        'a','b','c','d','e','f','g','h','i','j','k','l','m',
        'n','o','p','q','r','s','t','u','v','w','x','y','z',
        ' ', ',', '.'
    };
    private static int[] Base36Table = CreateBase36Table();



    private static int[] CreateBase36Table()
    {
        int[] table = new int[128];
        for (int i = 0; i < table.Length; i++)
            table[i] = -1;

        for (int i = 0; i < 10; i++)
            table['0' + i] = i;

        for (int i = 0; i < 26; i++)
        {
            table['a' + i] = 10 + i;
            table['A' + i] = 10 + i;
        }

        return table;
    }



    public override void _Ready()
    {
        global_values = GetNode("/root/GlobalValues");
    }



    public static GDictionary GetPageString(string hex, int wall, int shelf, int book, int page)
    {
        int pageSize  = (int)global_values.Get("LINES") * (int)global_values.Get("WORDS");
        int totalSize = pageSize * (int)global_values.Get("PAGES");

        BigInteger bookValue = GetBook(hex, wall, shelf, book);

        bookValue = BigInteger.DivRem(bookValue, BigInteger.Pow(29, (int)global_values.Get("TITLE")), out BigInteger remainder);

        int titleValue = (int)remainder;

        GD.Print("Book value: " + bookValue);
        GD.Print("Title value: " + titleValue);

        string bookString = GetPageFromBookValue(bookValue, page, pageSize, totalSize);
        string titleString = DecToBase29(titleValue);

        return new GDictionary
        {
            {"title" , titleString},
            {"book" , bookString}
        };
    }



    private static BigInteger GetBook(string hex, int wall, int shelf, int book)
    {

        string bookKey = $"{hex}|{wall}|{shelf}|{book}";
        if (bookKey == cachedBookKey)
        {
            BenchmarkTime("Book value retrieved from cache (skipped recalculation).");
            return cachedBookValue;
        }

        BigInteger hexValue;
        if (hex == cachedHex)
        {
            hexValue = cachedHexValue;
            BenchmarkTime("Hex retrieved from cache (skipped re-parsing).");
        }
        else
        {
            hexValue       = FromBase36(hex);
            cachedHex      = hex;
            cachedHexValue = hexValue;
        }

        BigInteger bookValue = hexValue;
        bookValue = bookValue * (int)global_values.Get("WALLS")   + wall;
        bookValue = bookValue * (int)global_values.Get("SHELVES") + shelf;
        bookValue = bookValue * (int)global_values.Get("BOOKS")   + book;

        cachedBookKey   = bookKey;
        cachedBookValue = bookValue;

        BenchmarkTime("Calculated book value.");

        return bookValue;
    }



    private static BigInteger FromBase36(string value)
    {
        BigInteger result = 0;

        ReadOnlySpan<char> input = value.AsSpan();

        foreach (char c in input)
        {
            int digit = Base36Table[c];

            if (digit == -1)
                throw new ArgumentException($"Invalid character '{c}' in hex string.");

            result = result * 36 + digit;
        }

        BenchmarkTime("Converted from base-36.");

        return result;
    }



    private static string GetPageFromBookValue(BigInteger bookValue, int page, int pageSize, int totalSize)
    {
        int startFromRight = totalSize - (page + 1) * pageSize;

        BigInteger shifted = bookValue / BigInteger.Pow(29, startFromRight);
      
        var result = DecToBase29(shifted, pageSize);

        BenchmarkTime("Extracted page from book value.");

        return new string(result);
    }


    private static string DecToBase29(BigInteger value, int stringLength = -1)
    {
        if (stringLength != -1)
        {
            char[] result = new char[stringLength];
            for (int i = stringLength - 1; i >= 0; i--)
            {
                value = BigInteger.DivRem(value,  29, out BigInteger remainder);
                result[i] = Base29Characters[(int)remainder];
            }
            return new string(result);
        }
        else
        {
            List<char> result = new List<char>();
            do
            {
                value = BigInteger.DivRem(value, 29, out BigInteger remainder);
                result.Add(Base29Characters[(int)remainder]);
            } while (value > 0);

            result.Reverse();
            return new string(result.ToArray());
        }
    }


    private static void BenchmarkTime(string message)
    {
        ulong currentTime = Time.GetTicksMsec();
        ulong debugTime   = (ulong)global_values.Get("debug_time");

        GD.Print(((currentTime - debugTime) / 1000.0).ToString("F3") + "s — " + message);

        global_values.Set("debug_time", (long)currentTime);
    }
}